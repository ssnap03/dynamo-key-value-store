defmodule Dynamo.Client do
    import Emulation, only: [send: 2]
  
    import Kernel,
      except: [spawn: 3, spawn: 1, spawn_link: 1, spawn_link: 3, send: 2]
  
    @moduledoc """
    A client that can be used to connect and send
    requests to the RSM.
    """
    alias __MODULE__
    @enforce_keys [:client]
    defstruct(
      client: nil,
      coordinator_node: nil
      )
  
    @doc """
    Construct a new Dynamo Client. This takes an ID of
    any process that is in the RSM. We rely on
    redirect messages to find the correct leader.
    """
   
    def new_client(client_id, server_id) do
      %Client{client: client_id, coordinator_node: server_id}
    end
  
    
    @doc """
    Send a get request to the RSM.
    """
    def get(client_id, server_id, key) do
      
      send(server_id, {:get, key})
    end
  
    def set(client,replica,key,value) do
  
      send(replica,{:put,key,value})

    end

    def check_view(client,replica) do
  
      send(replica,:check_view)

    end

    def kill(client,replica) do
  
      send(replica,:kill)

    end

    def revive(client,replica) do
  
      send(replica,:revive)

    end

    # def check_kv_store(client,replica) do
  
    #   send(replica,:check_kv_store)

    # end
  end