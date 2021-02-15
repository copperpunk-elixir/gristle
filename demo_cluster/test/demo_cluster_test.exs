defmodule DemoClusterTest do
  use ExUnit.Case
  doctest DemoCluster

  test "greets the world" do
    assert DemoCluster.hello() == :world
  end
end
