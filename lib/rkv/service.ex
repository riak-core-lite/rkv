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

  def put_quorum(k, v, n, w, timeout_ms) do
    quorum_cmd(k, {:put, {k, v}}, n, w, timeout_ms)
  end

  def get_quorum(k, n, w, timeout_ms) do
    quorum_cmd(k, {:get, k}, n, w, timeout_ms)
  end

  def delete_quorum(k, n, w, timeout_ms) do
    quorum_cmd(k, {:delete, k}, n, w, timeout_ms)
  end

  defp quorum_cmd(k, cmd, n, w, timeout_ms) do
    ref = make_ref()
    opts = %{ref: ref, from: self(), w: w, wait_timeout_ms: timeout_ms}
    :riak_core_quorum_statem.quorum_request({"rkv", k}, cmd, n, Rkv.Service, Rkv.VNode_master, opts)

    receive do
      {^ref, res} -> res
    end
  end
end
