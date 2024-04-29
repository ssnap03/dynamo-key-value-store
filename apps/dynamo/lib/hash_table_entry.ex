defmodule Dynamo.HashTableEntry do
  @moduledoc """
  Object entry for Dynamo, contain object_value, object_version(vector_clock), hash
  """
  alias Dynamo.HashTableEntry
  alias __MODULE__
  @enforce_keys [:value, :vector_clock, :hash]
  defstruct(
    value: nil,
    vector_clock: nil,
    hash: nil,
  )
  @doc """
  Return a HashTableEntry for putting in to the hash_table
  """
  @spec putObject(non_neg_integer(), %{}, non_neg_integer()):: %HashTableEntry{
    value: non_neg_integer(),
    vector_clock: %{},
    hash: non_neg_integer()
  }
  def putObject(value, vector_clock, hash) do
    %HashTableEntry{
      value: value,
      vector_clock: vector_clock,
      hash: hash
    }
  end
end