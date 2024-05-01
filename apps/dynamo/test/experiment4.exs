
defmodule DynamoTest do
    use ExUnit.Case
    import Emulation, only: [spawn: 2, send: 2, timer: 2]
  
    import Kernel,
      except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2, exit: 2]
  
    test "check eventual consistency" do
        Emulation.init()
        
        # Emulation.append_fuzzers([Fuzzers.delay(50)])
        view = [:a, :b, :c]
        base_config =
            Dynamo.new_configuration(view, 1, 1, 400_000, 4000, 8000)
    
        #pid = spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:d, fn -> Dynamo.init_dynamo_node(base_config) end)
        spawn(:e, fn -> Dynamo.init_dynamo_node(base_config) end)

        client =
            spawn(:client, fn ->
            client = Dynamo.Client.new_client(:client, :a) 
            end)
        
        {count_b, count_c, count_e} = check_eventual_consistency(client, view, 0, 0, 0, 0)
        IO.puts("count_b = #{inspect(count_b)}; count_c = #{inspect(count_c)}; count_e = #{inspect(count_e)}")
        
        handle = Process.monitor(client)
        # Timeout.
        receive do
            {:DOWN, ^handle, _, _, _} -> true
        # after
        # 20_000 -> assert false
        end
  
    after
      Emulation.terminate()
    end

    def check_eventual_consistency(client, view, loopi, count_b, count_c, count_e) do
        {count_b, count_c, count_e} =
            if loopi >= 10 do
                {count_b, count_c, count_e}
            else
                Dynamo.Client.kill(client, :b)
                Dynamo.Client.kill(client, :c)
                Dynamo.Client.kill(client, :e)

                receive do 
                    after 4_000 ->          
                        Dynamo.Client.set(client, :a, "a", "100")
                    receive do 
                        {:put, key, :ok, :a} -> true
                        _ -> false
                    end 
                end 
        
                Dynamo.Client.revive(client, :b)
                Dynamo.Client.revive(client, :c)
                Dynamo.Client.revive(client, :e)

                Process.sleep(10000)

                # 5ms -> 4,4,7 r=1 w=1 n=5
                # 400ms -> 6,5,8 r=1 w=1 n=5
                # 800ms -> 8,8,7 r=1 w=1 n=5
                # 1500ms -> 9,8,7 r=1 w=1 n=5
                # 1800ms -> 9,10,10 r=1 w=1 n=5
                # 2000ms -> 8,7,10 r=1 w=1 n=5
                # 2500ms -> 10,9,10 r=1 w=1 n=5
                # 3000ms -> 8,6,9 r=1 w=1 n=5
                # 4000ms -> 10,10,10 r=1 w=1 n=5
                # 5000ms -> 9,10,9 r=1 w=1 n=5


                Dynamo.Client.get(client, :b, "a")
                count_b = receive do 
                    {:get, key, vals, :b} -> 
                        if Enum.at(vals, 0) == "100" do
                            count_b+1
                        else
                            count_b
                        end
                end

                Dynamo.Client.get(client, :c, "a")
                count_c = receive do 
                    {:get, key, vals, :c} -> 
                        if Enum.at(vals, 0) == "100" do
                            count_c+1
                        else
                            count_c
                        end
                end

                Dynamo.Client.get(client, :e, "a")
                count_e = receive do 
                    {:get, key, vals, :e} -> 
                        if Enum.at(vals, 0) == "100" do
                            count_e+1
                        else
                            count_e
                        end
                end

                check_eventual_consistency(client, view, loopi+1, count_b, count_c, count_e)

            end
            
        {count_b, count_c, count_e}
    end
    
  end
  
  
  
  