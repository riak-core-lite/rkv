defmodule Rkv.KV.ETS do
  @behaviour Rkv.KV

  defmodule State do
    defstruct [:table_name, :table_id]
  end

  def init(%{uid: uid}) do
    table_name = String.to_atom("kv_ets_#{inspect(uid)}")
    ets_opts = [:set, {:write_concurrency, false}, {:read_concurrency, false}]
    table_id = :ets.new(table_name, ets_opts)

    {:ok, %State{table_name: table_name, table_id: table_id}}
  end

  def put(state, key, value) do
    true = :ets.insert(state.table_id, {key, value})
    :ok
  end

  def get(state, key) do
    case :ets.lookup(state.table_id, key) do
      [] ->
        {:error, :not_found}

      [{_, value}] ->
        {:ok, value}
    end
  end

  def delete(state, key) do
    true = :ets.delete(state.table_id, key)
    :ok
  end

  def is_empty(state) do
    :ets.first(state.table_id) == :"$end_of_table"
  end

  def dispose(state) do
    true = :ets.delete(state.table_id)
    :ok
  end

  def reduce(state, fun, acc0) do
    :ets.foldl(fun, acc0, state.table_id)
  end
end
