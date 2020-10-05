defmodule RkvTest do
  use ExUnit.Case
  doctest Rkv

  test "KV.ETS get" do
    {:ok, state} = Rkv.KV.ETS.init(%{uid: :erlang.unique_integer()})

    {:error, :not_found} = Rkv.KV.ETS.get(state, :k1)
    :ok = Rkv.KV.ETS.delete(state, :k1)

    :ok = Rkv.KV.ETS.put(state, :k2, :v2)
    {:ok, :v2} = Rkv.KV.ETS.get(state, :k2)
    :ok = Rkv.KV.ETS.delete(state, :k2)
    {:error, :not_found} = Rkv.KV.ETS.get(state, :k2)
  end
end
