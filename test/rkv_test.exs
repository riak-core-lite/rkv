defmodule RkvTest do
  use ExUnit.Case
  doctest Rkv

  test "greets the world" do
    assert Rkv.hello() == :world
  end
end
