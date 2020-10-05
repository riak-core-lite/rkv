defmodule RkvBenchTest do
  use ExUnit.Case
  doctest RkvBench

  test "greets the world" do
    assert RkvBench.hello() == :world
  end
end
