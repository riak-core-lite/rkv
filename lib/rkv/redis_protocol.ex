defmodule Rkv.Redis.Protocol do
  def run_command("SET", [key, val]) do
    :ok = Rkv.put(key, val)
    {:ok, nil}
  end

  def run_command("GET", [key]) do
    case Rkv.get(key) do
      {:ok, v} ->
        {:ok, nil, v}

      {:error, _reason} ->
        {:ok, nil, nil}
    end
  end

  def run_command("DEL", [key]) do
    :ok = Rkv.delete(key)
    {:ok, nil}
  end
end
