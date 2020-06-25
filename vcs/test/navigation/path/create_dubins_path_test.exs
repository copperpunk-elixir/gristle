defmodule Navigation.Path.CreateDubinsPathTest do
  use ExUnit.Case
  require Logger

  test "Create Dubins Path" do
    dubins = Navigation.Path.DubinsPath.new()
    assert dubins.path_cases[0].case_index == 0
    assert dubins.path_cases[0].flag == Navigation.Path.PathCase.orbit_flag()
    assert dubins.path_cases[2].case_index == 2
    assert dubins.path_cases[2].flag == Navigation.Path.PathCase.line_flag()

  end
end
