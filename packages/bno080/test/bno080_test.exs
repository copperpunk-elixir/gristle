defmodule Bno080Test do
  use ExUnit.Case
  doctest Bno080

  test "greets the world" do
    assert Bno080.hello() == :world
  end

  test "pass argument" do
    x = Bno080
    assert x.hello() == :world
  end
end
