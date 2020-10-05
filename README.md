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

