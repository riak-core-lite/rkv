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

