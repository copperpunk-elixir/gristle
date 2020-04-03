defmodule WorkshopTest do
  use ExUnit.Case
  doctest Workshop

  test "greets the world" do
    assert Workshop.hello() == :world
  end
end
