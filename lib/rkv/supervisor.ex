defmodule Rkv.Supervisor do
  use Supervisor

  def start_link do
    # riak_core appends _sup to the application name.
    Supervisor.start_link(__MODULE__, [], name: :rkv_sup)
  end

  def init(_args) do
    min_port = Application.get_env(:rkv, :redis_min_port, 6379)
    max_port = Application.get_env(:rkv, :redis_max_port, 6379)
    listener_opts = %{min_port: min_port, max_port: max_port}
    listener_sup = {:edis_listener_sup, {:edis_listener_sup, :start_link, [listener_opts]},
        :permanent, 1000, :supervisor, [:edis_listener_sup]}
    client_opts = %{command_runner_mod: Rkv.Redis.Protocol}
    client_sup = {:edis_client_sup, {:edis_client_sup, :start_link, [client_opts]},
        :permanent, 1000, :supervisor, [:edis_client_sup]}

    children = [
      worker(:riak_core_vnode_master, [Rkv.VNode], id: Rkv.VNode_master_worker),
      listener_sup,
      client_sup
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 5, max_seconds: 10)
  end
end

