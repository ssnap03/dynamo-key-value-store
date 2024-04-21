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
    version_map: %{},

    nonce: 0,

    R: 0,
    W: 0
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
      R: read_quorum,
      W: write_quorum
    }
  end

  @doc """
  Initialize server. Init vector clock.
  """
  def init_node(state) do
    new_vclock = Map.put(state.vclock, whoami(), 0)
    state = %{state | vclock: new_vclock}
    node(state)
  end

  def broadcast(state, message) do
    state.view
    |> Enum.map(fn pid ->
      send(pid, message) end)
  end

  def kv_store_get(state, key) do
    case Map.get(state.kv_store, key) do
      nil -> []
      v -> v
    end
  end

  def kv_store_set(state, key, v) do
    %{state | kv_store: Map.put(state.kv_store, key, v)}
  end

  def node(state) do
    receive do
      {sender, {:get, key}} ->

        nnc = state.nonce + 1

        state = %{state |
        nonce: nnc,
        response_count: Map.put(state.reponse_count, nnc, 0),
        version_map: Map.put(state.version_map, nnc, [])}

        msg = Dynamo.GetRequest.new(key, nonce)

        broadcast(state, msg)

        node(state)

      {sender, {:put, key, v}} ->

        # state = update_vector_clock(state)
        state = %{state | nonce: state.nonce+1}
        response_count = Map.put(state.response_count, state.nonce, {0, sender})
        value_version = {v, state.vclock}
        state = %{state | response_count: response_count, value_version: value_version}
        # state = kv_store_set(state, key, value_version)
        msg = Dynamo.PutRequest.new(key, value_version, state.nonce)
        broadcast(state,msg)

        node(state)

      {sender,
      %Dynamo.GetRequest{
        key: key,
        nonce: nonce
      }} ->
        msg = Dynamo.GetResponse.new(key, kv_store_get(state, key), nonce, true)
        send(sender, msg)
        node(state)

      {sender,
      %Dynamo.PutRequest{
        key: key,
        value: value,
        nonce: nonce
      }} ->
        state = kv_store_put(state,key,value)
        msg = Dynamo.PutResponse.new(key,nonce,true)
        send(sender,msg)
        node(state)

      {sender,
      %Dynamo.GetResponse{
        key: key,
        values: values,
        nonce: nonce,
        success: succ
      }} ->
        if Map.has_key?(state.responce_count, nonce) do
          {count, client} = Map.get(state.response.count, nonce)
          state = %{state | respnose_count: Map.put(state.response_count, nonce, {count+1, client})}

          if count+1 < state.R do
            # state = %{state | respnose_count: Map.put(state.response_count, nonce, state.response_count.get(nonce)+1) }
            node(state)
          else
          {count, client} = Map.get(state.response_count, nonce)
          send(client, {:get, key, values})
          state = %{state | response_count: Map.delete(state.response_count, nonce), value_version: Map.delete(state.value_version,nonce)}

          node(state)
          end
        end
        node(state)

      {sender,
      %Dynamo.PutResponse{
        key: key,
        nonce: nonce,
        success: succ
      }} ->

        if Map.has_key?(state.responce_count, nonce) do
          {count, client} = Map.get(state.response.count, nonce)
          state = %{state | respnose_count: Map.put(state.response_count, nonce, {count+1, client})}

          if count+1 < state.W do
            # state = %{state | respnose_count: Map.put(state.response_count, nonce, state.response_count.get(nonce)+1) }
            node(state)
          else
          {count, client} = Map.get(state.response_count, nonce)
          send(client, {:put, key, :ok})
          state = %{state | response_count: Map.delete(state.response_count, nonce)}
          node(state)
          end
        end
        node(state)
    end
  end




end
