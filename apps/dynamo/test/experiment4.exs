
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
        
        {count_b, count_c, count_e, count_d} = check_eventual_consistency(client, view, 0, 0, 0, 0, 0)
        IO.puts("count_b = #{inspect(count_b)}; count_c = #{inspect(count_c)}; count_e = #{inspect(count_e)}; count_d = #{inspect(count_d)}")
        
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

    def check_eventual_consistency(client, view, loopi, count_b, count_c, count_e, count_d) do
        {count_b, count_c, count_e, count_d} =
            if loopi >= 25 do
                {count_b, count_c, count_e, count_d}
            else
                Dynamo.Client.kill(client, :b)
                Dynamo.Client.kill(client, :c)
                Dynamo.Client.kill(client, :e)
                Dynamo.Client.kill(client, :d)

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
                Dynamo.Client.revive(client, :d)

                Process.sleep(10)
                # 0.72, 0.88, 0.96, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0
                # 10ms -> 0.72 r=1 w=1 f=1
                # 100ms -> 0.88 r=1 w=1 f=1
                # 500ms -> 0.96 r=1 w=1 f=1
                # 1000ms -> 25 r=1 w=1 f=1
                # 1500ms -> 25 r=1 w=1 f=1
                # 2000ms -> 25 r=1 w=1 f=1
                # 2500ms -> 25 r=1 w=1 f=1
                # 3000ms -> 25 r=1 w=1 f=1
                # 4000ms -> 25 r=1 w=1 f=1
                # 5000ms -> 25 r=1 w=1 f=1

                # 0.9, 0.9, 0.94, 0.94, 0.96, 1.0, 1.0, 1.0, 1.0, 1.0 
                # 10ms -> 23,22 r=1 w=1 f=2
                # 100ms -> 23,22 r=1 w=1 f=2
                # 500ms -> 24, 23 r=1 w=1 f=2
                # 1000ms -> 24,23 r=1 w=1 f=2
                # 1500ms -> 24,24 r=1 w=1 f=2
                # 2000ms -> 25, 25 r=1 w=1 f=2
                # 2500ms -> 25 r=1 w=1 f=2
                # 3000ms -> 25 r=1 w=1 f=2
                # 4000ms -> 25 r=1 w=1 f=2
                # 5000ms -> 25 r=1 w=1 f=2

                # 0.97, 0.96, 0.96, 0.96, 0.94, 0.97, 0.97, 1.0, 1.0, 1.0
                # 10ms -> 24, 24, 25 r=1 w=1 f=3
                # 100ms -> 24, 23, 25 r=1 w=1 f=3
                # 500ms -> 24, 24, 24 r=1 w=1 f=3
                # 1000ms -> 22, 25, 25 r=1 w=1 f=3
                # 1500ms -> 24, 22, 24 r=1 w=1 f=3
                # 2000ms -> 24, 24, 25 r=1 w=1 f=3
                # 2500ms -> 25, 24, 24 r=1 w=1 f=3
                # 3000ms -> 25, 25, 25 r=1 w=1 f=3
                # 4000ms -> 25, 25, 25 r=1 w=1 f=3
                # 5000ms -> 25, 25, 25 r=1 w=1 f=3

                # 0.9, 0.86, 0.89, 0.96, 0.98, 0.98, 1.0, 0.98, 1.0, 0.98
                # 10ms -> 22, 22, 24, 22 r=1 w=1 f=4
                # 100ms -> 21, 21, 22, 22 r=1 w=1 f=4
                # 500ms -> 22, 22, 24, 21 r=1 w=1 f=4
                # 1000ms -> 24, 24, 25, 23 r=1 w=1 f=4
                # 1500ms -> 24, 24, 25, 25 r=1 w=1 f=4
                # 2000ms -> 24, 25, 24, 25 r=1 w=1 f=4
                # 2500ms -> 25, 25, 25, 25 r=1 w=1 f=4
                # 3000ms -> 24, 25 , 25, 24 r=1 w=1 f=4
                # 4000ms -> 25, 25, 25, 25 r=1 w=1 f=4
                # 5000ms -> 24, 24, 25, 25 r=1 w=1 f=4


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

                Dynamo.Client.get(client, :d, "a")
                count_d = receive do 
                    {:get, key, vals, :d} -> 
                        if Enum.at(vals, 0) == "100" do
                            count_d+1
                        else
                            count_d
                        end
                end

                check_eventual_consistency(client, view, loopi+1, count_b, count_c, count_e, count_d)

            end
            
        {count_b, count_c, count_e, count_d}
    end
    
  end
  
  
  
  