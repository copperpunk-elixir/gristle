defmodule Navigation.Path.DubinsPath do
  require Logger
  defstruct [:path_cases, :skip_case_0, :skip_case_3]

  @spec new() :: struct()
  def new() do
    path_cases = Enum.reduce(0..4, %{}, fn (index, acc) ->
      path_case =
      if index == 2 do
        Navigation.Path.PathCase.new_line(index)
      else
        Navigation.Path.PathCase.new_orbit(index)
      end
      Map.put(acc, index, path_case)
    end)
    %Navigation.Path.DubinsPath{
      skip_case_0: nil,
      skip_case_3: nil,
      path_cases: path_cases
    }
  end
end
