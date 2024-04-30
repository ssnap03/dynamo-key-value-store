
defmodule DynamoTest do
  use ExUnit.Case
  import Emulation, only: [spawn: 2, send: 2, timer: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2, exit: 2]

 
#   test "check basic functionaly of kv-store : gets and puts" do
#     Emulation.init()
    
#     Emulation.append_fuzzers([Fuzzers.delay(50)])
#     view = [:a, :b, :c]
#     base_config =
#       Dynamo.new_configuration(view, 1, 1)

#     spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
#     spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
#     spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)

#     client =
#       spawn(:client, fn ->
#         client = Dynamo.Client.new_client(:client, :b)
      
#      Dynamo.Client.set(client, :b, "a", 100)
#      receive do 
#       {:put, key, :ok, :b} -> true
#       _ -> false
#      end 
#      Dynamo.Client.set(client, :c, "b", 200)
#      receive do 
#       {:put, key, :ok, :c} -> true
#       _ -> false
#      end 
#      Dynamo.Client.get(client, :b, "a")
#      receive do 
#         {:get, key, vals, :b} ->  assert Enum.at(vals, 0) == 100 
#         _ -> false
#       end 
#     Dynamo.Client.get(client, :a, "b")
#      receive do 
#         {:get, key, vals, :a} ->  assert Enum.at(vals, 0) == 200 
#         _ -> false
#       end 
# Dynamo.Client.get(client, :a, "c")
#      receive do 
#         {:get, key, vals, :a} ->  assert Enum.at(vals, 0) == nil
#         _ -> false
#       end 
     
        
#       end)

#     handle = Process.monitor(client)
#     # Timeout.
#     receive do
#       {:DOWN, ^handle, _, _, _} -> true
#     after
#       1_000 -> assert false
#     end
#   after
#     Emulation.terminate()
#   end
  
#   test "check basic functionality of gossip protocol" do
#     Emulation.init()
    
#     Emulation.append_fuzzers([Fuzzers.delay(50)])
#     view = [:a, :b, :c]
#     base_config =
#       Dynamo.new_configuration(view, 1, 1)

#     #pid = spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
#     spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
#     spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)

#     #Process.exit(pid, :normal)
#     receive do 
#       after 8_000 -> 
       

#         client =
#           spawn(:client, fn ->
#             client = Dynamo.Client.new_client(:client, :a)
          
#         Dynamo.Client.check_view(client, :a)
#         receive do 
#           {:a, view} -> assert(!Enum.member?(view, :b) == true)
#         end 
#         Dynamo.Client.check_view(client, :c)
#         receive do 
#           {:c, view} -> assert(!Enum.member?(view, :b) == true)
#         end 
#         end)

#         handle = Process.monitor(client)
#         # Timeout.
#         receive do
#           {:DOWN, ^handle, _, _, _} -> true
#         after
#           12_000 -> assert false
#         end
#       end
    

#   after
#     Emulation.terminate()
#   end

  test "check eventual consistency" do
    Emulation.init()
    
    Emulation.append_fuzzers([Fuzzers.delay(50)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 1)

    #pid = spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
    spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
    spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:client, :b)
      
     Dynamo.Client.set(client, :a, "a", "100")
     receive do 
      {:put, key, :ok, :a} -> true
      _ -> false
     end 
     Dynamo.Client.set(client, :c, "b", "200")
     receive do 
      {:put, key, :ok, :c} -> true
      _ -> false
     end 
   end)
    receive do 
      after 4_000 -> 
       
    spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
    end 

  


    #Process.exit(pid, :normal)
    receive do 
      after 4_000 -> 
       

        client =
          spawn(:client2, fn ->
            client = Dynamo.Client.new_client(:client2, :b)
          
        Dynamo.Client.get(client, :b, "a")
        receive do 
        {:get, key, vals, :b} -> IO.puts("hello i'm here")
                                   assert Enum.at(vals, 0) == "100"
        end 
        Dynamo.Client.get(client, :b, "b")
        receive do 
        {:get, key, vals, :b} ->  assert Enum.at(vals, 0) == "200" 
        end 
        end)

        handle = Process.monitor(client)
        # Timeout.
        receive do
          {:DOWN, ^handle, _, _, _} -> true
        after
          15_000 -> assert false
        end
      end
    

  after
    Emulation.terminate()
  end
  
end



