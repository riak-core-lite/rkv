defmodule Rkv.Service do
  def ping(v \\ 1) do
    send_cmd("ping#{v}", {:ping, v})
  end

  def put(k, v) do
    send_cmd(k, {:put, {k, v}})
  end

  def get(k) do
    send_cmd(k, {:get, k})
  end

  def delete(k) do
    send_cmd(k, {:delete, k})
  end

  defp send_cmd(k, cmd) do
    idx = :riak_core_util.chash_key({"rkv", k})
    pref_list = :riak_core_apl.get_primary_apl(idx, 1, Rkv.Service)

    [{index_node, _type}] = pref_list

    :riak_core_vnode_master.sync_command(index_node, cmd, Rkv.VNode_master)
  end
end
