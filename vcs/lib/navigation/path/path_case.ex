defmodule Navigation.Path.PathCase do
  require Logger

  @line_flag 1
  @orbit_flag 2
  defstruct [
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

  @spec new_line(integer()) :: struct()
  def new_line(case_index) do
    %Navigation.Path.PathCase{
      flag: @line_flag,
      case_index: case_index
    }
  end

  @spec new_orbit(integer()) :: struct()
  def new_orbit(case_index) do
    %Navigation.Path.PathCase{
      flag: @orbit_flag,
      case_index: case_index
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
