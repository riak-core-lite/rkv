defmodule Rkv.KV.DETS do
  @behaviour Rkv.KV

  defmodule State do
    defstruct [:table_name]
  end

  def init(%{uid: uid}) do
    table_name = String.to_charlist("dets_#{uid}")
    dets_opts = []
    {:ok, ^table_name} = :dets.open_file(table_name, dets_opts)

    {:ok, %State{table_name: table_name}}
  end

  def put(state, key, value) do
    :dets.insert(state.table_name, {key, value})
  end

  def get(state, key) do
    case :dets.lookup(state.table_name, key) do
      [] ->
        {:error, :not_found}

      [{_, value}] ->
        {:ok, value}
    end
  end

  def delete(state, key) do
    :dets.delete(state.table_name, key)
    :ok
  end

  def is_empty(state) do
    :dets.first(state.table_name) == :"$end_of_table"
  end

  def dispose(state) do
    :dets.delete_all_objects(state.table_name)
  end

  def reduce(state, fun, acc0) do
    :dets.foldl(fun, acc0, state.table_name)
  end
end
