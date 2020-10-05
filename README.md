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
