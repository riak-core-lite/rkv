# Rkv

## Tools and Versions

This tutorial assumes you have the following tools and versions installed:

Erlang/OTP 23.1
Elixir 1.10.4 (and Mix)
Git: any recent version is ok

The tutorial was also tested with this versions:

Erlang/OTP 22.3
Elixir 1.9.4

We assume you are running Linux, Mac OS X or WSL on Windows.

The tutorial was tested on Ubuntu 20.04, Mac OS X Catalina and Ubuntu 20.04 for
WSL on Windows 10.

## Installation Instructions

For instructions to install Erlang, see https://adoptingerlang.org/docs/development/setup/
For instructions to install Elixir, see https://elixir-lang.org/install.html

If you have no preferences you can use [asdf](https://asdf-vm.com), notice that
it requires a C compiler toolchain in order to compiler Erlang, see at the end
for instructions to do it on ubuntu-like systems, on Mac OS X it should work if
you have brew installed.

```
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.0
. ~/.asdf/asdf.sh
asdf plugin add erlang
asdf plugin add elixir

asdf list all elixir
asdf list all erlang

asdf install erlang 23.1
asdf install elixir 1.10.4-otp-23
```

Run these when you want to enable them:

```
asdf local erlang 23.1
asdf local elixir 1.10.4-otp-23
```

## Install Compiler Tools on Ubuntu

```
# required: basic tools and libraries needed
# (compiler, curses for the shell, ssl for crypto)
sudo apt-get -y install build-essential m4 libncurses5-dev libssl-dev autoconf unzip

# optonal: if you want odbc support (database connectivity)
sudo apt-get install unixodbc-dev

# optonal: if you want pdf docs you need apache fop and xslt tools and java (fop is a java project)
sudo apt-get install -y fop xsltproc default-jdk

# optional: if you want to build jinterface you need a JDK
sudo apt-get install -y default-jdk

# optional: if you want wx (desktop GUI modules)
sudo apt-get install -y libwxgtk3.0-dev
```

## Project Setup

Instal the Riak Core Lite Mix task:

```sh
$ mix archive.install hex rcl
```

```
Resolving Hex dependencies...
Dependency resolution completed:
New:
  rcl 0.1.9
* Getting rcl (Hex package)
All dependencies are up to date
Compiling 2 files (.ex)
Generated rcl app
Generated archive "rcl-0.1.9.ez" with MIX_ENV=prod
* creating /home/mariano/.asdf/installs/elixir/1.10.4-otp-23/.mix/archives/rcl-0.1.9
```

If you have an existing version installed it will ask you if you want to replace it, say `y`:

```
Found existing entry: /home/mariano/.asdf/installs/elixir/1.10.4-otp-23/.mix/archives/rcl-0.1.9
Are you sure you want to replace it with "rcl-0.1.9.ez"? [Yn]
```


Create a new project called `rkv`, to make it simpler don't change the name of the project unless you want to edit every single snippet :)

```sh
mix rcl new rkv
```

```
Creating project rkv, module Rkv
* creating README.md
* creating .formatter.exs
* creating .gitignore
* creating mix.exs
* creating lib
* creating lib/rkv.ex
* creating test
* creating test/test_helper.exs
* creating test/rkv_test.exs

Your Mix project was created successfully.
You can use "mix" to compile it, test it, and more:

    cd rkv
    mix test

Run "mix help" for more commands.
rcl: creating rkv/mix.exs
rcl: creating rkv/lib/rkv.ex
rcl: creating rkv/lib/rkv/application.ex
rcl: creating rkv/lib/rkv/vnode.ex
rcl: creating rkv/lib/rkv/service.ex
rcl: creating rkv/lib/rkv/supervisor.ex
rcl: creating rkv/config/config.exs
rcl: creating rkv/config/dev.exs
rcl: creating rkv/config/test.exs
rcl: creating rkv/config/ct.exs
rcl: creating rkv/config/node1.exs
rcl: creating rkv/config/node2.exs
rcl: creating rkv/config/node3.exs
rcl: creating rkv/rel/env.bat.eex
rcl: creating rkv/rel/env.sh.eex
rcl: creating rkv/rel/vm.args.eex
```

```sh
cd rkv
```

## Smoke Test

Get deps and compile:
```sh
cd rkv
mix deps.get

mix compile
```

Start the project and attach iex:

```sh
iex --name dev@127.0.0.1 -S mix run
```

Run this in iex:
```elixir
Rkv.Service.ping()
```

If after many logs you see something like this (the last number can be different):

```elixir
{:pong, 2, :"dev@127.0.0.1", 159851741583067506678528028578343455274867621888}
```

Then it works!

## Smaller Ring (for readability)

Edit `config/config.exs`:

```elixir
# chage
ring_creation_size: 64

# to
ring_creation_size: 16
```

Note: remove the `data` folder if it exists since it has a ring file of size 64:

```sh
rm -rf data
```

## A Simple Key Value Store

Abstract Key Value Store behaviour:

```elixir
# lib/rkv/kv.ex

defmodule Rkv.KV do
  @type kv_state :: term()

  @callback init(opts :: %{atom() => term()}) ::
              {:ok, state :: kv_state()} | {:error, reason :: term()}

  @callback put(state :: kv_state(), key :: term(), value :: term()) ::
              :ok | {:error, reason :: term()}
  @callback get(state :: kv_state(), key :: term()) ::
              {:ok, value :: term()} | {:error, reason :: term()}
  @callback delete(state :: kv_state(), key :: term()) ::
              :ok | {:error, reason :: term()}
end
```

In-memory implementation using [ETS](https://erlang.org/doc/man/ets.html):

```elixir
# lib/rkv/kv_ets.ex

defmodule Rkv.KV.ETS do
  @behaviour Rkv.KV

  defmodule State do
    defstruct [:table_name, :table_id]
  end

  def init(%{uid: uid}) do
    table_name = String.to_atom("kv_ets_#{inspect(uid)}")
    ets_opts = [:set, {:write_concurrency, false}, {:read_concurrency, false}]
    table_id = :ets.new(table_name, ets_opts)

    {:ok, %State{table_name: table_name, table_id: table_id}}
  end

  def put(state, key, value) do
    true = :ets.insert(state.table_id, {key, value})
    :ok
  end

  def get(state, key) do
    case :ets.lookup(state.table_id, key) do
      [] ->
        {:error, :not_found}

      [{_, value}] ->
        {:ok, value}
    end
  end

  def delete(state, key) do
    true = :ets.delete(state.table_id, key)
    :ok
  end
end
```

Some tests:
```elixir
# test/rkv_test.exs

defmodule RkvTest do
  use ExUnit.Case
  doctest Rkv

  test "KV.ETS get" do
    {:ok, state} = Rkv.KV.ETS.init(%{uid: :erlang.unique_integer()})

    {:error, :not_found} = Rkv.KV.ETS.get(state, :k1)
    :ok = Rkv.KV.ETS.delete(state, :k1)

    :ok = Rkv.KV.ETS.put(state, :k2, :v2)
    {:ok, :v2} = Rkv.KV.ETS.get(state, :k2)
    :ok = Rkv.KV.ETS.delete(state, :k2)
    {:error, :not_found} = Rkv.KV.ETS.get(state, :k2)
  end
end
```

Test it:
```sh
mix test
```

## Making the Key Value Store Distributed

Build 3 releases with different configurations to run them on the same machine:

```sh
MIX_ENV=node1 mix release node1
MIX_ENV=node2 mix release node2
MIX_ENV=node3 mix release node3
```

On terminal 1 (node1):
```sh
./_build/node1/rel/node1/bin/node1 start_iex
```

On terminal 2 (node2):
```sh
./_build/node2/rel/node2/bin/node2 start_iex
```

On terminal 3 (node3):
```sh
./_build/node3/rel/node3/bin/node3 start_iex
```

Run on node2 and node3:
```elixir
:riak_core.join('node1@127.0.0.1')
```

You should see something like this on node1:

```
[info]  'node3@127.0.0.1' joined cluster with status 'joining'
[info]  'node2@127.0.0.1' joined cluster with status 'joining'
```

Run on node1:
```elixir
:riak_core_claimant.plan()
:riak_core_claimant.commit()
```

Periodically run this until it stabilizes:

```elixir
:riak_core_console.member_status([])
```

You should see something like this on node1:

```
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      37.5%      --      'node1@127.0.0.1'
valid      31.3%      --      'node2@127.0.0.1'
valid      31.3%      --      'node3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

Periodically run this until it stabilizes:

```elixir
{:ok, ring} = :riak_core_ring_manager.get_my_ring()
:riak_core_ring.pretty_print(ring, [:legend])
```

You should see something like this on node1:

```
==================================== Nodes ====================================
Node a: 6 ( 37.5%) node1@127.0.0.1
Node b: 5 ( 31.3%) node2@127.0.0.1
Node c: 5 ( 31.3%) node3@127.0.0.1
==================================== Ring =====================================
abca|bcab|cabc|abca|
```

Run these (play with the argument value) and see which node and partition replies

```elixir
Rkv.Service.ping(3)
Rkv.Service.ping(5)
Rkv.Service.ping(7)
```

Let's add `get`, `put` and `delete` to `Rkv.Service` (`lib/rkv/service.ex`):

```elixir
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
```

Implement the commands in `lib/rkv/vnode.ex`, change init to:
```elixir
  def init([partition]) do
    kv_mod = Rkv.KV.ETS
    {:ok, state} = kv_mod.init(%{uid: partition})
    {:ok, %{partition: partition, kv_mod: kv_mod, kv_state: state}}
  end
```

Add the following 3 clauses after `:ping`:

```elixir
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
```

Compile and run:

```sh
mix compile
iex --name dev@127.0.0.1 -S mix run
```

Test the new functions:

```elixir
Rkv.Service.get(:k1)
```

```elixir
{{:error, :not_found}, :"dev@127.0.0.1", 639406966332270026714112114313373821099470487552}
```

```elixir
Rkv.Service.delete(:k1)
```

```elixir
{:ok, :"dev@127.0.0.1", 639406966332270026714112114313373821099470487552}
```

```elixir
Rkv.Service.put(:k2, :v2)
```

```elixir
{:ok, :"dev@127.0.0.1", 685078892498860742907977265335757665463718379520}
```

```elixir
Rkv.Service.get(:k2)
```

```elixir
{{:ok, :v2}, :"dev@127.0.0.1", 685078892498860742907977265335757665463718379520}
```

```elixir
Rkv.Service.delete(:k2)
```

```elixir
{:ok, :"dev@127.0.0.1", 685078892498860742907977265335757665463718379520}
```

```elixir
Rkv.Service.get(:k2)
```

```elixir
{{:error, :not_found}, :"dev@127.0.0.1", 685078892498860742907977265335757665463718379520}
```

## External API Module

Let's wrap `Rkv.Service` with an external API that doesn't expose so much
internal state that's only useful for learning , some tests and development but
not much for production:

Change `lib/rkv.ex` to:

```elixir
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
```

Compile and Run:
```
mix compile
iex --name dev@127.0.0.1 -S mix run
```

```elixir
Rkv.get(:k1)
```

```elixir
{:error, :not_found}
```

```elixir
Rkv.delete(:k1)
```

```elixir
:ok
```

```elixir
Rkv.put(:k2, :v2)
```

```elixir
:ok
```

```elixir
Rkv.get(:k2)
```

```elixir
{:ok, :v2}
```

```elixir
Rkv.delete(:k2)
```

```elixir
:ok
```

```elixir
Rkv.get(:k2)
```

```elixir
{:error, :not_found}
```

## Quorun Commands

Add the following functions to `lib/rkv/service.ex`:

```elixir
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
```

Compile and Run:

```sh
mix compile
iex --name dev@127.0.0.1 -S mix run
```

Try the new functions:

```elixir
Rkv.Service.get_quorum(:k1, 3, 2, 1000)
```

```elixir
{:ok,
 %{
   reason: :finished,
   result: [
     {{:error, :not_found}, :"rkv@127.0.0.1",
      822094670998632891489572718402909198556462055424},
     {{:error, :not_found}, :"rkv@127.0.0.1",
      639406966332270026714112114313373821099470487552}
   ]
 }}
```

```elixir
Rkv.Service.get_quorum(:k1, 3, 3, 1000)
```

```elixir
{:ok,
 %{
   reason: :finished,
   result: [
     {{:error, :not_found}, :"rkv@127.0.0.1",
      730750818665451459101842416358141509827966271488},
     {{:error, :not_found}, :"rkv@127.0.0.1",
      822094670998632891489572718402909198556462055424},
     {{:error, :not_found}, :"rkv@127.0.0.1",
      639406966332270026714112114313373821099470487552}
   ]
 }}
```

```elixir
Rkv.Service.put_quorum(:k1, :v1, 3, 3, 1000)
```

```elixir
{:ok,
 %{
   reason: :finished,
   result: [
     {:ok, :"rkv@127.0.0.1", 730750818665451459101842416358141509827966271488},
     {:ok, :"rkv@127.0.0.1", 822094670998632891489572718402909198556462055424},
     {:ok, :"rkv@127.0.0.1", 639406966332270026714112114313373821099470487552}
   ]
 }}
```

```elixir
Rkv.Service.get_quorum(:k1, 3, 3, 1000)
```

```elixir
{:ok,
 %{
   reason: :finished,
   result: [
     {{:ok, :v1}, :"rkv@127.0.0.1",
      730750818665451459101842416358141509827966271488},
     {{:ok, :v1}, :"rkv@127.0.0.1",
      639406966332270026714112114313373821099470487552},
     {{:ok, :v1}, :"rkv@127.0.0.1",
      822094670998632891489572718402909198556462055424}
   ]
 }}
```


```elixir
Rkv.Service.delete_quorum(:k1, 3, 3, 1000)
```

```elixir
{:ok,
 %{
   reason: :finished,
   result: [
     {:ok, :"rkv@127.0.0.1", 822094670998632891489572718402909198556462055424},
     {:ok, :"rkv@127.0.0.1", 730750818665451459101842416358141509827966271488},
     {:ok, :"rkv@127.0.0.1", 639406966332270026714112114313373821099470487552}
   ]
 }}
```


```elixir
Rkv.Service.get_quorum(:k1, 3, 3, 1000)
```

```elixir
{:ok,
 %{
   reason: :finished,
   result: [
     {{:error, :not_found}, :"rkv@127.0.0.1",
      822094670998632891489572718402909198556462055424},
     {{:error, :not_found}, :"rkv@127.0.0.1",
      730750818665451459101842416358141509827966271488},
     {{:error, :not_found}, :"rkv@127.0.0.1",
      639406966332270026714112114313373821099470487552}
   ]
 }}
```

## Testing

Add this deps to `mix.exs`:

```elixir
      {:ctex, "~> 0.1.0", env: :ct},
      {:rcl_test, "~> 0.2.0", env: :ct}
```

Fetch new deps:

```sh
mix deps.get
```

Create a folder for Common Test suite:

```sh
mkdir ct
```

Add our first Common Test suite:

Create a test suite at `ct/rkv_SUITE.exs`:

```elixir
defmodule Rkv_SUITE do
  def all() do
    [:simple_test]
  end

  def init_per_suite(config) do
    config
  end

  def end_per_suite(config) do
    config
  end

  def simple_test(_config) do
    1 = 1
  end
end
```

Run it:

```sh
MIX_ENV=ct mix ct
```

### Test a single node

Change `ct/rkv_SUITE.exs` to this:

```elixir
defmodule Rkv_SUITE do
  def all() do
    [:simple_test, :get_not_found]
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
end
```

Run it again:

```sh
MIX_ENV=ct mix ct
```

### Test a cluster


Add `cluster_join` test to `all` in `ct/rkv_SUITE.exs`:

```elixir
  def all() do
    [:simple_test, :get_not_found, :cluster_join]
  end
```

Add the test implementation at the end of `ct/rkv_SUITE.exs`:

```elixir
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
```

Run it again:

```sh
MIX_ENV=ct mix ct
```

## Benchmarking

Create a new project inside `rkv`:

```sh
mix new rkv_bench --sup
cd rkv_bench
```

Add the following dependency to `rkv_bench/mix.exs`:

```elixir
{:rcl_bench, "~> 0.1.0"}
```

Add `:rcl_bench` to `:extra_applications` in `rkv_bench/mix.exs`:

```elixir
extra_applications: [:logger, :rcl_bench],
```

Fetch deps:
```sh
mix deps.get
```

Create config folder
```sh
mkdir config
```

Add the following configuration to `rkv_bench/config/config.exs` to indicate which
module will implement the benchmark driver:

```elixir
import Config

config :rcl_bench,
  driver_module: RkvBench.Driver
```

Create the benchmark driver at `rkv_bench/lib/rkv_bench/driver.ex`:

```elixir
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
```

Compile:

```sh
mix compile
```

Start one **Rkv** node (`rkv` project) with a fixed cookie:

```sh
iex --cookie rcl-bench-cookie --name rkv@127.0.0.1 -S mix run
```

Notice that `--name rkv@127.0.0.1` is used in the driver.

Start a benchmark node (`rkv_bench` project) with the same cookie:

```sh
iex --cookie rcl-bench-cookie --name rkvbench@127.0.0.1 -S mix run
```

It will run for a minute (configured in the driver) and then log:

```
[info]  Benchmark finished
[info]  No Errors
```

It will generate this files (the name of the folder is configured in the driver):

```
./tests/put_single.csv
./tests/get_single.csv
./tests/get-own-puts_single.csv
```

Generate graphs:

```sh
mkdir benchmark_graphs
# ./scripts/latency.R <op> <csv-path> <image-path>
./scripts/latency.R get rkv_bench/tests/get_single.csv benchmark_graphs/latency_get_single.png
./scripts/latency.R put rkv_bench/tests/put_single.csv benchmark_graphs/latency_put_single.png
./scripts/latency.R get-own-puts rkv_bench/tests/get-own-puts_single.csv benchmark_graphs/latency_get-own-puts_single.png

# ./scripts/throughput.R <op> <csv-path> <image-path>
./scripts/throughput.R get rkv_bench/tests/get_single.csv benchmark_graphs/throughput_get_single.png
./scripts/throughput.R put rkv_bench/tests/put_single.csv benchmark_graphs/throughput_put_single.png
./scripts/throughput.R get-own-puts rkv_bench/tests/get-own-puts_single.csv benchmark_graphs/throughput_get-own-puts_single.png
```

To install R and libraries on ubuntu:

```sh
sudo apt install r-base
```

```sh
R
```

```r
install.packages("ggplot2")
install.packages("dplyr")
install.packages("scales")
install.packages("lubridate")
```

## Handoff

[source](https://riak.com/posts/technical/understanding-riak_core-handoff/index.html)

### What is a handoff?

A handoff is a transfer over the network of the keys and associated values from
one cluster member to another cluster member. There are four types of handoffs
that are supported in riak\_core: **ownership, hinted, repair, and resize**. Of
these, the most commonly encountered types are ownership and hinted.

#### Repairs

A repair handoff happens when your application explicitly calls
`riak_core_vnode_manager:repair/3` – an example implementation of this can be
found in `riak_kv_vnode:repair/1`. You might use this when your application
detects some kind of data error during a periodic integrity sweep – you have to
roll your own error detection code; riak\_core can’t intuit your application
semantics. Be aware that this operation is a big hammer and if there is a lot
of data in a vnode, you will pay a significant performance and latency penalty
while a repair is on-going between the (physical) nodes involved in the repair
operation.

#### Resize

riak\_core is set up to split its hash key space into partitions. The number of
keyspaces is defined internally by the “ring size”. By default the ring size is
64. (Currently this number must be a power of two.)

riak\_core will figure out how to move vnode data around your cluster members as
it conforms to this new partitioning directive and it uses the resize handoff
type to achieve this.

#### Ownership

An ownership handoff happens when a cluster member joins or leaves the cluster.
When a cluster is added or removed, riak\_core reassigns the (physical) nodes
responsible for each vnode and it uses the ownership handoff type to move the
data from its old home to its new home. (The reassignment activity occurs when
the “cluster plan” command is executed and the data transfers begin once the
“cluster commit” command is executed.)

#### Hinted

When the primary vnode for a particular part of the ring is offline, riak\_core
still accepts operations on it and routes those to a backup partition or
“fallback” as its sometimes known in the source code. When the primary vnode
comes back online, riak\_core uses a hinted handoff type to sync the current
vnode state from the fallback(s) to the primary. Once the primary is
synchronized, operations are routed to the primary once again.


Edit `lib/rkv/vnode.ex` after `@behaviour`:
```elixir
  require Logger
  require Record

  Record.defrecord(
    :fold_req_v2,
    :riak_core_fold_req_v2,
    Record.extract(:riak_core_fold_req_v2, from_lib: "riak_core/include/riak_core_vnode.hrl")
  )
```

replace this functions in `lib/rkv/vnode.ex`:

```elixir
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
```

We need more functions in our KV behavour to handle handoff, add the following at the end of `lib/rkv/kv.ex`:

```elixir
  @callback is_empty(state :: kv_state()) ::
              bool()
  @callback dispose(state :: kv_state()) ::
              :ok | {:error, reason :: term()}

  @callback reduce(
              state :: kv_state(),
              fun :: ({term(), term()}, term() -> term()),
              acc0 :: term()
            ) :: term()
```

Implement the new callbacks at the end of `lib/rkv/kv_ets.ex`:
```elixir
  def is_empty(state) do
    :ets.first(state.table_id) == :"$end_of_table"
  end

  def dispose(state) do
    true = :ets.delete(state.table_id)
    :ok
  end

  def reduce(state, fun, acc0) do
    :ets.foldl(fun, acc0, state.table_id)
  end
```

Clean existing cluster state:
```
rm -rf data
```

Rebuild:

```
MIX_ENV=node1 mix release --overwrite node1
MIX_ENV=node2 mix release --overwrite node2
MIX_ENV=node3 mix release --overwrite node3
```

Start node1:

```
./_build/node1/rel/node1/bin/node1 start_iex
```

Run in node1:

```elixir
for i <- :lists.seq(1, 100), do: Rkv.Service.put("k#{i}", i)
```

Start node2 in another terminal:

```
./_build/node2/rel/node2/bin/node2 start_iex
```

Run in node2:

```elixir
for i <- :lists.seq(101, 200), do: Rkv.Service.put("k#{i}", i)
```

Start node3 in another terminal:

```
./_build/node3/rel/node3/bin/node3 start_iex
```

Run in node3:

```elixir
for i <- :lists.seq(201, 300), do: Rkv.Service.put("k#{i}", i)
```

Run in node2 and node3:

```elixir
:riak_core.join('node1@127.0.0.1')
```

Run in node1:

```elixir
:riak_core_claimant.plan()
:riak_core_claimant.commit()
```

```
Periodically run this until it stabilizes:

```elixir
:riak_core_console.member_status([])
```

You should see something like this on node1:

```
================================= Membership ==================================
Status     Ring    Pending    Node
-------------------------------------------------------------------------------
valid      37.5%      --      'node1@127.0.0.1'
valid      31.3%      --      'node2@127.0.0.1'
valid      31.3%      --      'node3@127.0.0.1'
-------------------------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

Periodically run this until it stabilizes:

```elixir
{:ok, ring} = :riak_core_ring_manager.get_my_ring()
:riak_core_ring.pretty_print(ring, [:legend])
```

You should see something like this on node1:

```
==================================== Nodes ====================================
Node a: 6 ( 37.5%) node1@127.0.0.1
Node b: 5 ( 31.3%) node2@127.0.0.1
Node c: 5 ( 31.3%) node3@127.0.0.1
==================================== Ring =====================================
abca|bcab|cabc|abca|
```

Fetch some key and check which node returns it:

```elixir
Rkv.Service.get("k23")
```

