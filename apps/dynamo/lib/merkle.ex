defmodule Dynamo.Merkle do 
@moduledoc """
 Helpers for anti-entropy using merkle trees
 """

  # given a list of keys, extract the corresponding values from the hash table
  @spec get_values(%Dynamo{}, [any()]) :: [any()]
  def get_values(state, keys) do
    Enum.map(keys, fn k -> l = Map.get(state.kv_store,k)
                            {v,c} = Enum.at(l,length(l)-1)
                            v end)
  end
  
  # given a list of keys, extract the corresponding values from the hash table
  @spec get_keys(%Dynamo{}) :: [any()]
  def get_keys(state) do
    key_list = Map.keys(state.kv_store)
    IO.puts("here #{inspect(key_list)}")
    sorted_keys = Enum.sort(key_list)
        IO.puts("there #{inspect(sorted_keys)}")

    sorted_keys
  end


  @spec convert_to_hash_list(map())::list()
  def convert_to_hash_list(hash_table) do
    Enum.map(hash_table,fn({key,v}) -> {v.hash} end)
  end


  @spec retrieve_key_value(%Dynamo{}, non_neg_integer())::{any(),%Dynamo.HashTableEntry{}}
  def retrieve_key_value(state,val) do
    state.merkle_hash_table |> Enum.find(fn {key, v} -> v.hash == val end)
  end

   @spec hash_function(String.t()) :: String.t()
  def hash_function(metadata) do
    MerkleTree.Crypto.hash(metadata,:md5)
  end

  @spec update_merkle_tree(%Dynamo{}, non_neg_integer(), any(), non_neg_integer(), map(), atom()):: %Dynamo{}
  def update_merkle_tree(state, key, value, hash, vector_clock, sender) do
    state =
      if Map.has_key?(state.merkle_hash_table, key) do
        if Map.get(vector_clock, sender) >= Map.get(state.merkle_hash_table,key).vector_clock[sender] do
          vclock = Map.replace!(state.merkle_hash_table[key].vector_clock, sender, vector_clock[sender])
          temp_hash_entry = state.merkle_hash_table[key]
          temp_hash_entry = %{temp_hash_entry | vector_clock: vclock, value: value, hash: hash}
          temp_hash_table = Map.replace!(state.merkle_hash_table, key, temp_hash_entry)
          %{state | merkle_hash_table: temp_hash_table,
            kv_store: Map.put(state.kv_store, key, value) }
        else
          state 
        end
      else
        temp_hash_entry = Dynamo.HashTableEntry.putObject(value, vector_clock, hash)
        temp_hash_table = Map.put(state.merkle_hash_table, key, temp_hash_entry)
        %{state | merkle_hash_table: temp_hash_table,
            kv_store: Map.put(state.kv_store, key, value)}
      end

    keys = get_keys(state)
    values = get_values(state, keys)
    new_hash_tree = MerkleTree.new(values, &hash_function/1)
    state = %{state | merkle_tree: new_hash_tree}
  end


# @spec sync_merkle_trees(%Dynamo{}, atom()) :: any()
#   def sync_merkle_trees(state, neighbour) do
   
#     merkle_tree_root = state.merkle_tree.root()
#     state = %{state | merkle_children : merkle_tree_root.children}

#     if List.first(state.merkle_children) == nil do
#       hash = hash_tree_root.value
#       {key,entry} = retrieve_key_value(state, hash)
#       updated_hash_table_req = Dynamo.SynchronizationRequest.new(key,entry.value,entry.hash,entry.vector_clock)
#       send(neighbour, updated_hash_table_req)
#       state
#     else
#         left_child = List.first(state.merkle_children)
#         send(neighbour,{:MTCheck, hash_tree_root_left_child})
#         state
#     end
#   end
  

  def recurse_merkle_tree([head_b| tail_b], [head_a| tail_a], b_state, a_state, sender) do #sender is :a
    if(head_b.value == head_a.value) do 
            recurse_merkle_tree(tail_b, tail_a, b_state, a_state, sender)
    else 
        if length(head_b.root.children)==0 do 
            {key,entry} = retrieve_key_value(a_state, head_a.value)
            update_merkle_tree(b_state, key, entry.value, entry.hash, entry.vector_clock, sender )
        else 
            recurse_merkle_tree(tail_b++head_b.root.children, tail_a++head_a.root.children, b_state, a_state, sender)
        end
    end 
end

def recurse_merkle_tree([], [head_a| tail_a], b_state, a_state, sender) do #sender is :a
    recurse_merkle_tree([], tail_a++head_a.root.children, b_state, a_state, sender)
  end

def recurse_merkle_tree([], [head_a| []], b_state, a_state, sender) do #sender is :a
    {key,entry} = retrieve_key_value(a_state, head_a.value)
    update_merkle_tree(b_state, key, entry.value, entry.hash, entry.vector_clock, sender )
  end

def recurse_merkle_tree(list_b, [], b_state, a_state, sender) do #sender is :a
    b_state
end

def recurse_merkle_tree([], [], b_state, a_state, sender) do #sender is :a
    b_state
end
  
    

  @spec sync_merkle_trees(%Dynamo{}, %Dynamo{}, atom()) :: any()
  def sync_merkle_trees(b_state, a_state, sender) do
    #b_root = b_state.merkle_tree.root()
    #a_root = a_state.merkle_tree.root()
    if b_state.merkle_tree == %{} do 
      %{b_state | merkle_tree: a_state.merkle_tree, kv_store: a_state.kv_store, merkle_hash_table: a_state.merkle_hash_table}
    else
    if b_state.merkle_tree.root.value != a_state.merkle_tree.root.value do 
        recurse_merkle_tree(b_state.merkle_tree.root.children, a_state.merkle_tree.root.children, b_state, a_state, sender)
    else 
        b_state 
    end
    end
end
end



