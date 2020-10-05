defmodule Rkv.Application do
  use Application
  require Logger

  def start(_type, _args) do
    case Rkv.Supervisor.start_link() do
      {:ok, pid} ->
        :ok = :riak_core.register(vnode_module: Rkv.VNode)
        :ok = :riak_core_node_watcher.service_up(Rkv.Service, self())
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Unable to start Rkv supervisor because: #{inspect(reason)}")
    end
  end
end

