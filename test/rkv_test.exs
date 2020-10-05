defmodule RkvTest do
  use ExUnit.Case
  doctest Rkv
  alias Rkv.KV

  def reduce_fn(pair, acc_in) do
    [pair | acc_in]
  end

  test "KV.ETS get" do
    {:ok, state} = KV.ETS.init(%{uid: :erlang.unique_integer()})

    true = KV.ETS.is_empty(state)
    [] = KV.ETS.reduce(state, &reduce_fn/2, [])
    {:error, :not_found} = KV.ETS.get(state, :k1)
    :ok = KV.ETS.delete(state, :k1)

    :ok = KV.ETS.put(state, :k2, :v2)
    [{:k2, :v2}] = KV.ETS.reduce(state, &reduce_fn/2, [])
    false = KV.ETS.is_empty(state)
    {:ok, :v2} = KV.ETS.get(state, :k2)
    :ok = KV.ETS.delete(state, :k2)
    {:error, :not_found} = KV.ETS.get(state, :k2)
    :ok = KV.ETS.dispose(state)
  end

  test "KV.DETS get" do
    {:ok, state} = KV.DETS.init(%{uid: :erlang.unique_integer()})

    true = KV.DETS.is_empty(state)
    [] = KV.DETS.reduce(state, &reduce_fn/2, [])
    {:error, :not_found} = KV.DETS.get(state, :k1)
    :ok = KV.DETS.delete(state, :k1)

    :ok = KV.DETS.put(state, :k2, :v2)
    false = KV.DETS.is_empty(state)
    [{:k2, :v2}] = KV.DETS.reduce(state, &reduce_fn/2, [])
    {:ok, :v2} = KV.DETS.get(state, :k2)
    :ok = KV.DETS.delete(state, :k2)
    {:error, :not_found} = KV.DETS.get(state, :k2)
    :ok = KV.DETS.dispose(state)
  end
end
