defmodule PackageTesterTest do
  use ExUnit.Case
  doctest PackageTester

  test "greets the world" do
    assert PackageTester.hello() == :world
  end
end
