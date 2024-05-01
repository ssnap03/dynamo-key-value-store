defmodule Experiments do
    use ExUnit.Case
    import Emulation, only: [spawn: 2, send: 2, timer: 1]
  
    import Kernel,
      except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  
  
    def generate_random_string() do
      s = for _ <- 1..3, into: "", do: <<Enum.random('abcdefghijklmnopqrstuvwxyz')>>
    end
  
    def generate_random_val() do
      s = for _ <- 1..2, into: "", do: <<Enum.random('0123456789')>>
    end
  
    def generate_random_num() do
      Enum.random(0..10)
    end

    test "measure staleness" do
        Emulation.init()

        Emulation.append_fuzzers([Fuzzers.delay(200)])
        
        view = [:a, :b, :c, :d, :e]

        base_config = Dynamo.new_configuration(view, 1, 1)

        spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:d, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:e, fn -> Dynamo.init_dynamo_node(base_config) end)

        client =
            spawn(:client, fn ->
                client = Dynamo.Client.new_client(:client, :a)
                Dynamo.Client.set(client, :a, "begin", "first")
                keys = ["begin"]    
                keys = 
                    for x <- 1..20 do
                        random_server = Enum.random(view)
                        key =
                        if generate_random_num() < 5 do
                            # insert new-valur pair
                            key = generate_random_string()
                            val = generate_random_val()
                            Dynamo.Client.set(client, random_server, key, val)
                            key
                        else
                            #update some existing key 
                            key = Enum.random(keys)
                            val = generate_random_val()
                            Dynamo.Client.set(client, random_server, key, val)
                            key
                        end
                    end
                    IO.puts("keys = #{inspect(keys)}")    
                key = Enum.random(keys)
                val = "last"
                
                Dynamo.Client.set(client, :a, key, val)
                
                measure_staleness(client, view, key, val)
        end)        
        handle = Process.monitor(client)

        # Timeout.
        receive do
        {:DOWN, ^handle, _, _, _} -> true
        # after
        #     30_000 -> assert false
        end
    after
        Emulation.terminate()
    end

    def measure_staleness(client, view, key, val) do 

        view |> Enum.map(fn x -> Dynamo.Client.get(client, x, key) end)
            val_list =
                view
                |> Enum.map(fn x ->
                    receive do
                        {^x, {:get, key, val, _}} -> 
                            # IO.puts("key = #{inspect(key)}; val = #{inspect(val)}")
                            val
                    end
                end)  
            IO.puts("val_list = #{inspect(val_list)}")
            {stale, updated} = check_stale_vals(val_list, val, 0, 0)
            IO.puts("Num of times Stale data obtained: #{stale}" )
            IO.puts("Num of times Updated data obtained: #{updated}" )
    
    end

    def check_stale_vals([head|tail], val, stale, updated) do
        # if head == val do
        if Enum.member?(head, val) do
            updated = updated + 1
            check_stale_vals(tail, val, stale, updated)
        else
            stale = stale + 1
            check_stale_vals(tail, val, stale, updated)
        end
    end

    def check_stale_vals([], val, stale, updated) do
        {stale, updated}
    end
end