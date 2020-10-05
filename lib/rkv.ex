defmodule Rkv do
  def ping(v \\ 1) do
    {r, _, _} = Rkv.Service.ping(v)
    r
  end

  def put(k, v) do
    {r, _, _} = Rkv.Service.put(k, v)
    r
  end

  def get(k) do
    {r, _, _} = Rkv.Service.get(k)
    r
  end

  def delete(k) do
    {r, _, _} = Rkv.Service.delete(k)
    r
  end
end
