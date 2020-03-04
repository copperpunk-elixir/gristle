defmodule PackageTesterTest do
  use ExUnit.Case
  doctest PackageTester

  test "greets the world" do
    assert PackageTester.hello() == :world
  end

  test "hellos" do
    x = Adsadc
    y = Vl53tof
    assert x.hello() == :world
    assert y.hello() == :world
    person = "Meg"
    assert say_hi(x, person) == "Hello to #{person}" 
  end

  def say_hi(mod, person) do
    hello_fn = mod.get_hello_function()
    hello_fn.(person)
  end
end
