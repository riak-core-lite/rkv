defmodule Rkv.KV do
  @type kv_state :: term()

  @callback init(opts :: %{atom() => term()}) ::
              {:ok, state :: kv_state()} | {:error, reason :: term()}

  @callback put(state :: kv_state(), key :: term(), value :: term()) ::
              :ok | {:error, reason :: term()}
  @callback get(state :: kv_state(), key :: term()) ::
              {:ok, value :: term()} | {:error, reason :: term()}
  @callback delete(state :: kv_state(), key :: term()) ::
              :ok | {:error, reason :: term()}
end
