defmodule Rkv.VNode do
  @behaviour :riak_core_vnode
  require Logger
  require Record

  Record.defrecord(
    :fold_req_v2,
    :riak_core_fold_req_v2,
    Record.extract(:riak_core_fold_req_v2, from_lib: "riak_core/include/riak_core_vnode.hrl")
  )

  def start_vnode(partition) do
    :riak_core_vnode_master.get_vnode_pid(partition, __MODULE__)
  end

  def init([partition]) do
    kv_mod = Application.get_env(:rkv, :kv_mod, Rkv.KV.ETS)
    {:ok, state} = kv_mod.init(%{uid: partition})
    {:ok, %{partition: partition, kv_mod: kv_mod, kv_state: state}}
  end

  def handle_command({:ping, v}, _sender, state = %{partition: partition}) do
     {:reply, {:pong, v + 1, node(), partition}, state}
  end

  def handle_command({:get, k}, _sender, state) do
    result = state.kv_mod.get(state.kv_state, k)
    {:reply, {result, node(), state.partition}, state}
  end

  def handle_command({:put, {k, v}}, _sender, state) do
    result = state.kv_mod.put(state.kv_state, k, v)
    {:reply, {result, node(), state.partition}, state}
  end

  def handle_command({:delete, k}, _sender, state) do
    result = state.kv_mod.delete(state.kv_state, k)
    {:reply, {result, node(), state.partition}, state}
  end

  def handoff_starting(_dest, state) do
    Logger.debug("handoff_starting #{state.partition}")
    {true, state}
  end

  def handoff_cancelled(state) do
    Logger.debug("handoff_cancelled #{state.partition}")
    {:ok, state}
  end

  def handoff_finished(_dest, state) do
    Logger.debug("handoff_finished #{state.partition}")
    {:ok, state}
  end

  def handle_handoff_command(fold_req_v2() = fold_req, _sender, state) do
    Logger.debug("handoff #{state.partition}")
    foldfun = fold_req_v2(fold_req, :foldfun)
    acc0 = fold_req_v2(fold_req, :acc0)

    acc_final =
      state.kv_mod.reduce(
        state.kv_state,
        fn {k, v}, acc_in ->
          Logger.debug("handoff #{state.partition}: #{k} #{v}")
          foldfun.(k, v, acc_in)
        end,
        acc0
      )

    {:reply, acc_final, state}
  end

  def handle_handoff_command(_request, _sender, state) do
    Logger.debug("Handoff generic request, ignoring #{state.partition}")
    {:noreply, state}
  end

  def is_empty(state) do
    is_empty = state.kv_mod.is_empty(state.kv_state)
    Logger.debug("is_empty #{state.partition}: #{is_empty}")
    {is_empty, state}
  end

  def terminate(reason, state) do
    Logger.debug("terminate #{state.partition}: #{reason}")
    :ok
  end

  def delete(state) do
    Logger.debug("delete #{state.partition}")
    state.kv_mod.dispose(state.kv_state)
    {:ok, state}
  end

  def handle_handoff_data(bin_data, state) do
    {k, v} = :erlang.binary_to_term(bin_data)
    state.kv_mod.put(state.kv_state, k, v)
    Logger.debug("handle_handoff_data #{state.partition}: #{k} #{v}")
    {:reply, :ok, state}
  end

  def encode_handoff_item(k, v) do
    Logger.debug("encode_handoff_item #{k} #{v}")
    :erlang.term_to_binary({k, v})
  end

  def handle_coverage(_req, _key_spaces, _sender, state) do
    {:stop, :not_implemented, state}
  end

  def handle_exit(_pid, _reason, state) do
    {:noreply, state}
  end

  def handle_overload_command(_, _, _) do
    :ok
  end

  def handle_overload_info(_, _idx) do
    :ok
  end
end
