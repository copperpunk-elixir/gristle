defmodule AdsadcTest do
  use ExUnit.Case
  use Bno080
  doctest Adsadc

  test "greets the world" do
    assert Adsadc.hello() == :world
  end

  test "uses Bno080" do
    x = Bno080
    assert x.hello() == :world
  end
end
