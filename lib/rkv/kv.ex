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

  @callback is_empty(state :: kv_state()) ::
              bool()
  @callback dispose(state :: kv_state()) ::
              :ok | {:error, reason :: term()}

  @callback reduce(
              state :: kv_state(),
              fun :: ({term(), term()}, term() -> term()),
              acc0 :: term()
            ) :: term()
end
