defmodule Dynamo.GetRequest do
  @moduledoc """
  Get RPC request.
  """
  alias __MODULE__

  # Require that any GetRequest contains
  # a :key.
  @enforce_keys [
    :key,
    :nonce
  ]
  defstruct(
    key: nil,
    nonce: nil
  )

  @doc """
  Create a new GetRequest
  """

  @spec new(
          any(),
          non_neg_integer()
        ) ::
          %GetRequest{
            key: any(),
            nonce: non_neg_integer()
          }
  def new(
        key,
        nonce
      ) do
    %GetRequest{
      key: key,
      nonce: nonce
    }
  end
end

defmodule Dynamo.GetResponse do
  @moduledoc """
  Response for the GetRequest
  """
  alias __MODULE__
  @enforce_keys [:key, :values, :nonce, :success]
  defstruct(
    key: nil,
    values: nil,
    nonce: nil,
    success: nil
  )

  @doc """
  Create a new GetResponse.
  """
  @spec new(any(), list(any()), non_neg_integer(), boolean()) ::
          %GetResponse{
            key: any(),
            values: list(any()),
            nonce: non_neg_integer(),
            success: boolean()
          }
  def new(key, value, nonce, success) do
    %GetResponse{
      key: key,
      values: value,
      nonce: nonce,
      success: success
    }
  end
end

defmodule Dynamo.PutRequest do
  @moduledoc """
  Put RPC request.
  """
  alias __MODULE__

  # Require that any GetRequest contains
  # a :key.
  @enforce_keys [
    :key,
    :value,
    :nonce
  ]
  defstruct(
    key: nil,
    value: nil,
    nonce: nil
  )

  @doc """
  Create a new PutRequest
  """
  @spec new(
          any(),
          any(),
          non_neg_integer()
        ) ::
          %PutRequest{
            key: any(),
            value: any(),
            nonce: non_neg_integer()
          }
  def new(
        key,
        value,
        nonce
      ) do
    %PutRequest{
      key: key,
      value: value,
      nonce: nonce
    }
  end
end

defmodule Dynamo.PutResponse do
  @moduledoc """
  Response for the PutRequest
  """
  alias __MODULE__
  @enforce_keys [:key, :nonce, :success]
  defstruct(
    key: nil,
    nonce: nil,
    success: nil
  )

  @doc """
  Create a new PutResponse.
  """
  @spec new(any(), non_neg_integer(), boolean()) ::
          %PutResponse{
            key: any(),
            nonce: non_neg_integer(),
            success: boolean()
          }
  def new(key, nonce, success) do
    %PutResponse{
      key: key,
      nonce: nonce,
      success: success
    }
  end
end

#   defmodule Dynamo.SynchronizationRequest do
#   alias __MODULE__
#   @enforce_keys [:key, :value, :hash, :vector_clock]
#   defstruct(
#     key: nil,
#     value: nil,
#     hash: nil,
#     vector_clock: nil
#   )

#   @spec new(non_neg_integer(),non_neg_integer(),non_neg_integer(), map())::
#   %SynchronizationRequest{
#     key: non_neg_integer(),
#     value: non_neg_integer(),
#     hash: non_neg_integer(),
#     vector_clock: map()
#   }
#   def new(key, value, hash, vector_clock) do
#     %SynchronizationRequest{
#       key: key,
#       value: value,
#       hash: hash,
#       vector_clock: vector_clock
#     }
#   end
#   end

# defmodule Dynamo.SynchronizationResponse do
#   alias __MODULE__
#   @enforce_keys [:succ]
#   defstruct(
#     succ
#   )
#   @spec new(boolean)::
#   %SynchronizationResponse{
#     success: boolean
#   }
#   def new(succ) do
#     %SynchronizationResponse{
#       success: succ
#     }
#   end
# end
