defmodule Navigation.Dubins.PathCase do
  require Logger

  @line_flag 1
  @orbit_flag 2
  defstruct [
    :type,
    :flag,
    :case_index,
    :r,
    :q,
    :c,
    :rho,
    :turn_direction,
    :zi,
    :v_des
  ]

  @spec new_line(integer(), atom()) :: struct()
  def new_line(case_index, type) do
    %Navigation.Dubins.PathCase{
      flag: @line_flag,
      case_index: case_index,
      type: type
    }
  end

  @spec new_orbit(integer(), atom()) :: struct()
  def new_orbit(case_index, type) do
    %Navigation.Dubins.PathCase{
      flag: @orbit_flag,
      case_index: case_index,
      type: type
    }
  end

  @spec line_flag() :: integer()
  def line_flag() do
    @line_flag
  end

  @spec orbit_flag() :: integer()
  def orbit_flag() do
    @orbit_flag
  end
end
