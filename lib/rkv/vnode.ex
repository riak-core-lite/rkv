defmodule Rkv.VNode do
  @behaviour :riak_core_vnode

  def start_vnode(partition) do
    :riak_core_vnode_master.get_vnode_pid(partition, __MODULE__)
  end

  def init([partition]) do
    kv_mod = Rkv.KV.ETS
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
    {true, state}
  end

  def handoff_cancelled(state) do
    {:ok, state}
  end

  def handoff_finished(_dest, state) do
    {:ok, state}
  end

  def handle_handoff_command(_fold_req, _sender, state) do
    {:noreply, state}
  end

  def is_empty(state) do
    {true, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  def delete(state) do
    {:ok, state}
  end

  def handle_handoff_data(_bin_data, state) do
    {:reply, :ok, state}
  end

  def encode_handoff_item(_k, _v) do
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
