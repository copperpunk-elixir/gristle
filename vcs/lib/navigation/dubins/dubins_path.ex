defmodule Navigation.Dubins.DubinsPath do
  require Logger
  @enforce_keys [:path_cases, :skip_case_0, :skip_case_3]
  defstruct [:path_cases, :skip_case_0, :skip_case_3]

  @spec new() :: struct()
  def new() do
    %Navigation.Dubins.DubinsPath{
      skip_case_0: nil,
      skip_case_3: nil,
      path_cases: []
    }
  end
end
