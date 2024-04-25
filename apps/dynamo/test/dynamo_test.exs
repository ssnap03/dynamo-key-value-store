
defmodule DynamoTest do
  use ExUnit.Case
  import Emulation, only: [spawn: 2, send: 2, timer: 2]

  import Kernel,
    except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2, exit: 2]

  def check_view(views) do 
    receive do
      
      {:a, view} -> m = Map.put(views, :a, view)
              if(length(Map.get(views, :c)) != 0) do 
                views
              else 
                check_view(views)
              end
      {:c, view} -> m = Map.put(views, :c, view)
              if(length(Map.get(views, :a)) != 0) do 
                views
              else 
                check_view(views)
              end
      
      _ -> check_view(views)
    end
  
  end
  test "check basic functionaly of kv-store : gets and puts" do
    Emulation.init()
    
    Emulation.append_fuzzers([Fuzzers.delay(50)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 1)

    spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
    spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
    spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)

    client =
      spawn(:client, fn ->
        client = Dynamo.Client.new_client(:client, :b)
      
     Dynamo.Client.set(client, :b, "a", 100)
     receive do 
      {:put, key, :ok, :b} -> true
      _ -> false
     end 
     Dynamo.Client.set(client, :c, "b", 200)
     receive do 
      {:put, key, :ok, :c} -> true
      _ -> false
     end 
     Dynamo.Client.get(client, :b, "a")
     receive do 
        {:get, key, vals, :b} ->  assert Enum.at(vals, 0) == 100 
        _ -> false
      end 
    Dynamo.Client.get(client, :a, "b")
     receive do 
        {:get, key, vals, :a} ->  assert Enum.at(vals, 0) == 200 
        _ -> false
      end 
Dynamo.Client.get(client, :a, "c")
     receive do 
        {:get, key, vals, :a} ->  assert Enum.at(vals, 0) == nil
        _ -> false
      end 
     
        
      end)

    handle = Process.monitor(client)
    # Timeout.
    receive do
      {:DOWN, ^handle, _, _, _} -> true
    after
      1_000 -> assert false
    end
  after
    Emulation.terminate()
  end

  test "check basic functionality of gossip protocol" do
    Emulation.init()
    
    Emulation.append_fuzzers([Fuzzers.delay(50)])
    view = [:a, :b, :c]
    base_config =
      Dynamo.new_configuration(view, 1, 1)

    #pid = spawn(:b, fn -> Dynamo.init_dynamo_node(base_config) end)
    spawn(:c, fn -> Dynamo.init_dynamo_node(base_config) end)
    spawn(:a, fn -> Dynamo.init_dynamo_node(base_config) end)

    #Process.exit(pid, :normal)
    receive do 
      after 30_000 -> 
        send(:a, :check_view)
        send(:c, :check_view)
        views = check_view(%{})
        a_view = Map.get(views, :a)
        c_view = Map.get(views, :c)

        assert(!Enum.member?(a_view, :b) == true)
        assert(!Enum.member?(c_view, :b) == true)
      
    end
    

  after
    Emulation.terminate()
  end
end



