defmodule RkvBench.Driver do
  @behaviour :rcl_bench_driver

  def new(id) do
    node = :"rkv@127.0.0.1"
    state = %{id: id, node: node, existing: %{}, mod: Rkv}
    {:ok, state}
  end

  def run(:get, keygen, _valuegen, %{node: node, mod: mod} = state) do
    key = keygen.()
    {_, _} = :rpc.call(node, mod, :get, [key])
    {:ok, state}
  end

  def run(:put, keygen, valuegen, %{existing: existing, node: node, mod: mod} = state) do
    key = keygen.()
    value = valuegen.()
    :ok = :rpc.call(node, mod, :put, [key, value])
    {:ok, %{state | existing: Map.put(existing, key, true)}}
  end

  def run(:get_own_puts, _keygen, _valuegen, %{existing: existing} = state)
      when map_size(existing) == 0 do
    {:ok, state}
  end

  def run(:get_own_puts, _keygen, _valuegen, %{existing: existing, node: node, mod: mod} = state) do
    max = Enum.count(existing)
    take = :rand.uniform(max) - 1
    {key, _} = Enum.at(existing, take)
    {:ok, _} = :rpc.call(node, mod, :get, [key])
    {:ok, state}
  end

  def terminate(_, _) do
    :ok
  end

  # config callbacks

  def mode() do
    {:ok, {:rate, :max}}
  end

  # Number of concurrent workers
  def concurrent_workers() do
    {:ok, 2}
  end

  # Test duration (minutes)
  def duration() do
    {:ok, 1}
  end

  # Operations (and associated mix)
  def operations() do
    {:ok, [{:get_own_puts, 3}, {:put, 10}, {:get, 2}]}
  end

  # Base test output directory
  def test_dir() do
    {:ok, "tests"}
  end

  # Key generators
  # {uniform_int, N} - Choose a uniformly distributed integer between 0 and N
  def key_generator() do
    {:ok, {:uniform_int, 100_000}}
  end

  # Value generators
  # {fixed_bin, N} - Fixed size binary blob of N bytes
  def value_generator() do
    {:ok, {:fixed_bin, 100}}
  end

  def random_algorithm() do
    {:ok, :exsss}
  end

  def random_seed() do
    {:ok, {1, 4, 3}}
  end

  def shutdown_on_error() do
    false
  end
end
