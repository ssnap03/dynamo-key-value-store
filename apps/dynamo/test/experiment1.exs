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

    test "measure time in obtaining consistency" do
        Emulation.init()

        start_time = System.monotonic_time()

        Emulation.append_fuzzers([Fuzzers.delay(200)])
        
        view = [:a, :b, :c, :d, :e]

        base_config = Dynamo.new_configuration(view, 1, 1)

        spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:d, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:e, fn -> Dynamo.init_dynamo_node(base_config) end)

        count = 0

        client =
            spawn(:client, fn ->
                client = Dynamo.Client.new_client(:client, :a)
        
            count = measure_read_probability(client, view, 0, 0)

            IO.puts("count = #{inspect(count)}")
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

    def measure_read_probability(client, view, loopi, count) do
        count = 
            if loopi >= 20 do
                count
            else 
                IO.puts("loopi = #{inspect(loopi)}")
                random_server = Enum.random(view)

                key = generate_random_string()
                val = generate_random_val()
                
                Dynamo.Client.set(client, random_server, key, val)

                tim = Emulation.timer(10, :t1)
                
                receive do
                    :t1 ->
                        # Emulation.cancel_timer(tim)
                        rand_get_server = Enum.random(view)
                        Dynamo.Client.get(client, rand_get_server, key)        
                        measure_read_probability_helper(client, view, key, val, rand_get_server, loopi, count)
                end
            end
        count
    end

    def measure_read_probability_helper(client, view, key, val, rand_get_server, loopi, count) do
        # IO.puts("#{inspect(rand_get_server)}")
        receive do
            {rand_get_server, {:get, key, vals, rand_get_server}} -> 
                if Enum.at(vals, 0) == val do
                    measure_read_probability(client, view, loopi+1, count+1)
                else
                    measure_read_probability(client, view, loopi+1, count)
                end
        end
        # measure_read_probability_helper(client, view, key, val , rand_get_server, loopi, count)
    end
end