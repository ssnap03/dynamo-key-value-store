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
        # view = [:a, :b, :c]

        base_config = Dynamo.new_configuration(view, 3, 3, 400_000, 200_000, 400_000)

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
            if loopi >= 50 do
                count
            else 
                IO.puts("loopi = #{inspect(loopi)}")
                random_server = Enum.random(view)

                key = generate_random_string()
                val = generate_random_val()
                
                Dynamo.Client.set(client, random_server, key, val)
                
                tim = Emulation.timer(1500, :t1)
                # 0.84, 0.92, 0.98, 1.0, 1.0, 1.0
                # 0.90, 0.90, 0.98, 1.0, 1.0, 1.0

                # r w n d   c
                # 0.74, 0.78, 0.92, 0.96, 1.0, 1.0
    
                # 1 1 3 200 37
                # 1 1 3 300 39
                # 1 1 3 500 46
                # 1 1 3 750 48
                # 1 1 3 1000 50
                # 1 1 3 1500 50

                # 0.72, 0.84, 0.88, 0.96, 1.0, 1.0
                # 1 2 3 200 36 
                # 1 2 3 300 42 
                # 1 2 3 500 44 
                # 1 2 3 750 48 
                # 1 2 3 1000 50
                # 1 2 3 1500 50

                # 0.80, 0.90, 0.98, 0.98, 1.0, 1.0
                # 2 1 3 200 40
                # 2 1 3 300 45
                # 2 1 3 500 49
                # 2 1 3 750 49
                # 2 1 3 1000 50
                # 2 1 3 1500 50

                # 0.72, 0.84, 0.88, 0.98, 1.0, 1.0
                # 1 1 5 200 36
                # 1 1 5 300 42
                # 1 1 5 500 44
                # 1 1 5 750 49
                # 1 1 5 1000 50
                # 1 1 5 1500 50

               
                # 0.76, 0.92, 0.96, 1.0, 1.0, 1.0
                # 2 3 5 200 38
                # 2 3 5 300 46
                # 2 3 5 500 48
                # 2 3 5 750 50
                # 2 3 5 1000 50
                # 2 3 5 1500 50

                # 0.84, 0.94, 0.98, 1.0, 1.0, 1.0
                # 3 2 5 200 42
                # 3 2 5 300 47
                # 3 2 5 500 49
                # 3 2 5 750 50
                # 3 2 5 1000 50
                # 3 2 5 1500 50

                # 0.78, 0.80, 0.84, 0.98, 0.98, 1.0
                # 1 1 7 200 39
                # 1 1 7 300 40
                # 1 1 7 500 42
                # 1 1 7 750 49
                # 1 1 7 1000 49
                # 1 1 7 1500 50

                # 0.78, 0.90, 0.98, 1.0, 1.0, 1.0
                # 3 4 7 200 39
                # 3 4 7 300 45
                # 3 4 7 500 49
                # 3 4 7 750 50
                # 3 4 7 1000 50
                # 3 4 7 1500 50

                # 0.90, 0.96, 0.98, 1.0, 1.0, 1.0
                # 4 3 7 200 45
                # 4 3 7 300 48
                # 4 3 7 500 49
                # 4 3 7 750 50
                # 4 3 7 1000 50
                # 4 3 7 1500 50
                
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