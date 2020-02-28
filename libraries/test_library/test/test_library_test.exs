defmodule TestLibraryTest do
  use ExUnit.Case
  doctest TestLibrary

  test "greets the world" do
    assert TestLibrary.hello() == :world
  end
end
