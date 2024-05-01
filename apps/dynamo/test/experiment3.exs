
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
            Dynamo.new_configuration(view, 1, 1, 4000, 4000, 8000)
    
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
        
        count = check_eventual_consistency(client, view, 0, 0)
        IO.puts("count = #{inspect(count)}")
        
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

    def check_eventual_consistency(client, view, loopi, count) do
        count =
            if loopi >= 10 do
                count
            else
                Dynamo.Client.kill(client, :b)

                receive do 
                    after 4_000 ->          
                        Dynamo.Client.set(client, :a, "a", "100")
                    receive do 
                        {:put, key, :ok, :a} -> true
                        _ -> false
                    end 
                end 
        
                Dynamo.Client.revive(client, :b)
      

                Process.sleep(5)
                
                Dynamo.Client.get(client, :b, "a")
                receive do 
                    {:get, key, vals, :b} -> 
                        if Enum.at(vals, 0) == "100" do
                            check_eventual_consistency(client, view, loopi+1, count+1)
                        else
                            check_eventual_consistency(client, view, loopi+1, count)
                        end
                end
            end
            
        count
    end
    
  end
  
  
  
  