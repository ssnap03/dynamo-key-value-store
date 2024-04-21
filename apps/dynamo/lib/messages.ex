defmodule Dynamo.GetRequest do
  @moduledoc """
  Get RPC request.
  """
  alias __MODULE__

  # Require that any GetRequest contains
  # a :key.
  @enforce_keys [
    :key
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
    key: nil
    values: nil,
    nonce, nil,
    success: nil
  )

  @doc """
  Create a new GetResponse.
  """
  @spec new(any(), list(any()), non_neg_integer(), boolean()) ::
          %GetResponse{
            key: any(),
            value: list(any()),
            nonce: non_neg_integer(),
            success: boolean()
          }
  def new(key, value, nonce, success) do
    %GetResponse{
      key: key,
      value: value,
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
    key: nil
    nonce, nil,
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