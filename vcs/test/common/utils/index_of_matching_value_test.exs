defmodule Common.Utils.IndexOfMatchingValueTest do
  use ExUnit.Case
  require Logger


  test "Get index of matching value test" do
    a = [
      %{x: 1, y: 0},
      %{x: 2, y: 0},
      %{x: 3, y: 0},
      %{x: 4, y: -1}
    ]
    x3_index = Common.Utils.index_for_embedded_value(a, :x, 3)
    assert x3_index == 2
    nil_index = Common.Utils.index_for_embedded_value(a, :x, 5)
    assert nil_index == nil
    y_index = Common.Utils.index_for_embedded_value(a, :y, -1)
    assert y_index == 3

  end
end
