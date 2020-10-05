defmodule Rkv_SUITE do
  def all() do
    [:simple_test, :get_not_found, :cluster_join]
  end

  def init_per_suite(config) do
    common_config = %{
      app: :rkv,
      build_env: "dev",
      data_dir_name: "rkv-data",
      setup_node_fn: fn (_) -> :ok end,
    }
    nodes_config = %{dev1: %{base_port: 10015}}
    :rcl_test.init_nodes(__MODULE__, config, common_config, nodes_config)
  end

  def end_per_suite(config) do
    config
  end

  def simple_test(_config) do
    1 = 1
  end

  def get_not_found(config) do
    [node] = :test_server.lookup_config(:nodes, config)
    key = :k1
    {:error, :not_found} = :rpc.call(node, Rkv, :get, [key])
  end

  def cluster_join(config0) do
    common_config = %{
      app: :rkv,
      build_env: "dev",
      data_dir_name: "rkv-data",
      setup_node_fn: fn (_) -> :ok end,
    }
    nodes_config = %{
      node1: %{base_port: 10115},
      node2: %{base_port: 10215},
      node3: %{base_port: 10315},
    }
    config = :rcl_test.init_nodes(__MODULE__, config0, common_config, nodes_config)
    [node1, node2, node3] = :test_server.lookup_config(:nodes, config)

    :ok = :rcl_test.add_nodes_to_cluster(node1, [node2, node3])

    key = :k1
    val = :v1
    {:error, :not_found} = :rpc.call(node1, Rkv, :get, [key])
    {:error, :not_found} = :rpc.call(node2, Rkv, :get, [key])
    {:error, :not_found} = :rpc.call(node3, Rkv, :get, [key])

    :ok = :rpc.call(node1, Rkv, :put, [key, val])
    {:ok, ^val} = :rpc.call(node2, Rkv, :get, [key])
  end
end
