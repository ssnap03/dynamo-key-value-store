defmodule Dynamo do
  @moduledoc """
  An implementation of Dynamo.
  """
  # Shouldn't need to spawn anything from this module, but if you do
  # you should add spawn to the imports.
  import Emulation, only: [send: 2, timer: 1, now: 0, whoami: 0]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]

  require Fuzzers
  # This allows you to use Elixir's loggers
  # for messages. See
  # https://timber.io/blog/the-ultimate-guide-to-logging-in-elixir/
  # if you are interested in this. Note we currently purge all logs
  # below Info
  require Logger

  # This structure contains all the process state
  # required by the Raft protocol.
  defstruct(
    # The list of current servers.
    view: nil,

    kv_store: %{},

    vclock: %{},

    # quorum count per client
    response_count: %{},

    # value-version map
    value_version: %{},

    nonce: 0,

    read_quorum: 0,
    write_qourum: 0,

    # gossip timer
    gossip_timeout: 15_000,
    gossip_timer: nil,
    rtt_timeout: 400,
    rtt_timer: nil,
    no_ack_timeout: 800,
    no_ack_timer: nil,
    gossip_term: 0,
    k: 2,
    neighbour: nil
  )

  @doc """
  Create state for an initial Dynamo cluster. Each
  process should get an appropriately updated version
  of this state.
  """
  @spec new_configuration(
          [atom()],
          non_neg_integer(),
          non_neg_integer()
        ) :: %Dynamo{}
  def new_configuration(
        view,
        read_quorum,
        write_quorum
      ) do
    %Dynamo{
      view: view,
      read_quorum: read_quorum,
      write_qourum: write_quorum
    }
  end

  """
  vector clock helpers
  """
  def uniq(list) do
      uniq(list, MapSet.new())
  end

  defp uniq([x | rest], found) do
    {v,vc} = x
    if MapSet.member?(found, vc) do
      uniq(rest, found)
    else
      [x | uniq(rest, MapSet.put(found, vc))]
    end
  end

  defp uniq([], _) do
    []
  end

  def get_recent_value([head1|tail], l2, acc) do
      acc = loop1(head1, l2, acc)
      get_recent_value(tail, l2, acc)
  end

  def get_recent_value([], l2, acc) do
    acc
  end


  def loop1(head1, [head2 | tail2], acc) do
    if compare_vectors(head1.vc, head2.vc) != :before do
      loop1(head1, tail2, acc)
    else
      acc
    end
  end

  def loop1(val1, [], acc) do
    acc ++ [val1]
  end

  def remove_stale_values(l1, l2) do
    uniq(get_recent_value(l1, l2, []) ++ get_recent_value(l2, l1, []))
  end

  @spec combine_vector_component(
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
  defp combine_vector_component(x, y) do
    if x > y do
      x 
    else 
      y
    end
  end

  @spec combine_vector_clocks(map(), map()) :: map()
  def combine_vector_clocks(vclock1, vclock2) do
    Map.merge(vclock1, vclock2, fn _k, v1, v2 -> combine_vector_component(v1, v2) end)
  end

  def update_vector_clock(state) do
    %{state | vclock: Map.update!(state.vclock, whoami(), fn x -> x + 1 end)}
  end

  @spec equalize_vclock_lengths(map(), map()) :: map()
  defp equalize_vclock_lengths(v1, v2) do
    v1_add = for {k, _} <- v2, !Map.has_key?(v1, k), do: {k, 0}
    Map.merge(v1, Enum.into(v1_add, %{}))
  end

  # Compare two components of a vector clock c1 and c2.
  # Return @before if a vector of the form [c1] happens before [c2].
  # Return @after if a vector of the form [c2] happens before [c1].
  # Return @concurrent if neither of the above two are true.
  @spec compare_component(
          non_neg_integer(),
          non_neg_integer()
        ) :: :before | :after | :concurrent
  def compare_component(c1, c2) do
    cond do
      c1 < c2 -> :before
      c1 > c2 -> :after
      c1 = c2 -> :concurrent
    end
  end

  @doc """
  Compare two vector clocks v1 and v2.
  Returns @before if v1 happened before v2.
  Returns @hafter if v2 happened before v1.
  Returns @concurrent if neither of the above hold.
  """
  @spec compare_vectors(map(), map()) :: :before | :after | :concurrent
  def compare_vectors(v1, v2) do
    # First make the vectors equal length.
    v1 = equalize_vclock_lengths(v1, v2)
    v2 = equalize_vclock_lengths(v2, v1)
    # `compare_result` is a list of elements from
    # calling `compare_component` on each component of
    # `v1` and `v2`. Given this list you need to figure
    # out whether
    compare_result =
      Map.values(
        Map.merge(v1, v2, fn _k, c1, c2 -> compare_component(c1, c2) end)
      )
    a = Enum.all?(compare_result, fn x -> x == :before or x == :concurrent end)
    b = Enum.any?(compare_result, fn x -> x == :before end)
    c = Enum.all?(compare_result, fn x -> x == :after or x == :concurrent end)
    d = Enum.any?(compare_result, fn x -> x == :after end)
    e = Enum.all?(compare_result, fn x -> x == :concurrent end)
    cond do 
      a and b -> :before
      c and d -> :after
      b and d or e -> :concurrent
    end
  end


  @doc """
  Initialize server. Init vector clock.
  """
  def init_dynamo_node(state) do
    new_vclock = Map.put(state.vclock, whoami(), 0)
    state = %{state | vclock: new_vclock}
    state = reset_gossip_timer(state)
    dynamo_node(state)
  end

  def broadcast(state, message) do
    state.view
    |> Enum.map(fn pid ->
      send(pid, message) end)
  end

  def broadcast_to_others(state, message) do
    state.view
    |> Enum.filter(fn pid -> pid != whoami() end)
    |> Enum.map(fn pid -> send(pid, message) end)
  end

  def kv_store_get(state, key) do
    case Map.get(state.kv_store, key) do
      nil -> []
      v -> v
    end
  end

  def kv_store_put(state, key, v) do
    {val, clock} = v
    if Map.get(state.kv_store, key) == nil do 
      %{state | vclock: combine_vector_clocks(state.vclock, clock),
                        kv_store: Map.put(state.kv_store, key, [v])}
    else 
      cur_vals = Map.get(state.kv_store, key)
      concurrent_vals = Enum.filter(cur_vals, fn cur_v -> {_, cur_clock} = cur_v
                        if compare_vectors(cur_clock, clock) == :concurrent do cur_v end end)
    
      concurrent_vals = uniq([v] ++ concurrent_vals)
      %{state | vclock: combine_vector_clocks(state.vclock, clock),
                        kv_store: Map.put(state.kv_store, key, concurrent_vals)}
    end
  end

  # Save a handle to the gossip timer.
  @spec save_gossip_timer(%Dynamo{}, reference()) :: %Dynamo{}
  defp save_gossip_timer(state, timer) do
    %{state | gossip_timer: timer}
  end

  @spec reset_gossip_timer(%Dynamo{}) :: %Dynamo{}
  defp reset_gossip_timer(state) do
    if state.gossip_timer != nil do
      Emulation.cancel_timer(state.gossip_timer)
    end
    timer = Emulation.timer(state.gossip_timeout, :gossip_timeout)
    state = save_gossip_timer(state, timer)
    state
  end

  def get_random_neighbour(state) do
    random_neighbour = state.view |> Enum.filter(fn pid -> pid != whoami() end) |> Enum.random()
    state = %{state | gossip_term: state.gossip_term+1, neighbour: random_neighbour}
    send(random_neighbour,{:ping,state.gossip_term})
    rtt= Emulation.timer(state.rtt_timeout,:rtt_timeout)
    no_ack= Emulation.timer(state.no_ack_timeout,:no_ack_timeout)
    %{state | rtt_timer: rtt,no_ack_timer: no_ack}
  end

  def dynamo_node(state) do
    receive do
      {sender, {:get, key}} ->

        nnc = state.nonce + 1

        state = %{state |
        nonce: nnc,
        response_count: Map.put(state.response_count, nnc, {0,sender}),
        value_version: Map.put(state.value_version, nnc, [])}

        msg = Dynamo.GetRequest.new(key, nnc)

        broadcast(state, msg)

        dynamo_node(state)

      {sender, {:put, key, v}} ->

        state = update_vector_clock(state)
        state = %{state | nonce: state.nonce+1}
        response_count = Map.put(state.response_count, state.nonce, {0, sender})
        value_version = {v, state.vclock}
        state = %{state | response_count: response_count}
        # state = kv_store_set(state, key, value_version)
        msg = Dynamo.PutRequest.new(key, value_version, state.nonce)
        broadcast(state,msg)

        dynamo_node(state)

      {sender,
      %Dynamo.GetRequest{
        key: key,
        nonce: nonce
      }} ->
        msg = Dynamo.GetResponse.new(key, kv_store_get(state, key), nonce, true)
        send(sender, msg)
        dynamo_node(state)

      {sender,
      %Dynamo.PutRequest{
        key: key,
        value: value,
        nonce: nonce
      }} ->
        state = kv_store_put(state,key,value)
        msg = Dynamo.PutResponse.new(key,nonce,true)
        send(sender,msg)
        dynamo_node(state)

      {sender,
      %Dynamo.GetResponse{
        key: key,
        values: values,
        nonce: nonce,
        success: succ
      }} ->
        if Map.has_key?(state.response_count, nonce) do
          #IO.puts("#{inspect(Map.get(state.response_count, nonce))}")
          {count, client} = Map.get(state.response_count, nonce)
          state = %{state | response_count: Map.put(state.response_count, nonce, {count+1, client})}
          #IO.puts("#{inspect(Map.get(state.value_version, nonce))}")
          non_stale_values = remove_stale_values(Map.get(state.value_version, nonce),  values)
          if count+1 < state.read_quorum do
            # state = %{state | respnose_count: Map.put(state.response_count, nonce, state.response_count.get(nonce)+1) }
            state = %{state | value_version: Map.put(state.value_version, nonce, non_stale_values)}
            dynamo_node(state)
          else
            return_vals = Enum.map(non_stale_values, fn {v, _} -> v end)
            send(client, {:get, key, return_vals, sender})
            state = %{state | response_count: Map.delete(state.response_count, nonce), value_version: Map.delete(state.value_version,nonce)}

            dynamo_node(state)
          end
        end
        dynamo_node(state)

      {sender,
      %Dynamo.PutResponse{
        key: key,
        nonce: nonce,
        success: succ
      }} ->

        if Map.has_key?(state.response_count, nonce) do
          {count, client} = Map.get(state.response_count, nonce)
          state = %{state | response_count: Map.put(state.response_count, nonce, {count+1, client})}

          if count+1 < state.write_qourum do
            # state = %{state | respnose_count: Map.put(state.response_count, nonce, state.response_count.get(nonce)+1) }
            dynamo_node(state)
          else
            {count, client} = Map.get(state.response_count, nonce)
            send(client, {:put, key, :ok, sender})
            state = %{state | response_count: Map.delete(state.response_count, nonce)}
            dynamo_node(state)
          end
        end
        dynamo_node(state)

      :gossip_timeout -> 
        IO.puts("gossip timeout in #{inspect(whoami())}")
        state = reset_gossip_timer(state)
        state = get_random_neighbour(state)
        IO.puts("random node chosen #{inspect(state.neighbour)} by #{inspect(whoami())}")
        dynamo_node(state)

      {sender, {:ping, term}} -> 
        IO.puts("ping received in #{inspect(whoami())} from #{inspect(sender)}")
        send(sender, {:ack, state.neighbour, term})
        dynamo_node(state)

      {sender, {:ack, neighbour, term}} -> 
        if term == state.gossip_term do
          Emulation.cancel_timer(state.rtt_timer)
          Emulation.cancel_timer(state.no_ack_timer)
          broadcast_to_others(state, {neighbour, :running})
          IO.puts("ack received in #{inspect(whoami())} from #{inspect(sender)}")

          """
          if(!Enum.member?(state.view, neighbour)) do
            state = %{state | view: [state.view | neighbour]}
            dynamo_node(state)
          else
            dynamo_node(state)
          end
          """
          dynamo_node(state)
        else
          dynamo_node(state)
        end

      {sender, {node, :running}} ->
              IO.puts("running received in #{inspect(whoami())} from #{inspect(sender)}")

        if(!Enum.member?(state.view,  node)) do
          state = %{state | view: state.view ++ [node]}
          dynamo_node(state)
        else
          dynamo_node(state)
        end

      :rtt_timeout -> 
      IO.puts("rtt timed out in node #{inspect(whoami())}")
        neighbours = Enum.take_random(state.view, state.k)
        message = {:ping_on_rtt, self(), state.neighbour, state.gossip_term}
        neighbours |>  Enum.map(fn pid -> send(pid, message) end)
        dynamo_node(state)

      {sender,  {:ping_on_rtt, pinger, neighbour, term}} ->
              IO.puts("ping_on_rtt received in #{inspect(whoami())} from #{inspect(sender)}")

        send(neighbour, {:indirect_ping_on_rtt, neighbour, pinger, term})
        dynamo_node(state)

      {sender,  {:indirect_ping_on_rtt, neighbour, pinger, term}} ->
              IO.puts("indirect_ping received in #{inspect(whoami())} from #{inspect(sender)}")

        send(sender, {:indirect_ack_on_rtt, neighbour, pinger, term})
        dynamo_node(state)

      
      {sender,  {:indirect_ack_on_rtt, neighbour, pinger, term}} ->
              IO.puts("indirect_ack received in #{inspect(whoami())} from #{inspect(sender)}")

        send(pinger, {:ack, term})
        dynamo_node(state)

      :no_ack_timer -> 
              IO.puts("no ack timer  received in #{inspect(whoami())} ")

        broadcast(state.view, {state.neighbour, :failed})
        dynamo_node(state)
        

      {sender, {node, :failed}} ->
              IO.puts("failed received in #{inspect(whoami())} from #{inspect(sender)}")

        if(Enum.member?(state.view,  node)) do
          state = %{state | view: List.delete(state.view,  node)}
          dynamo_node(state)
        else
          dynamo_node(state)
        end

      {sender, :check_view} -> 
              IO.puts("check view received in #{inspect(whoami())} ")

        send(sender, state.view)
        dynamo_node(state)
    end
  end
end
