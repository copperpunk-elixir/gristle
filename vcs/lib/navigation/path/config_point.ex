defmodule Navigation.Path.ConfigPoint do
  require Logger

  defstruct [
    :pos,
    # :wim1,
    # :wip1,
    # :qim1,
    # :qi,
    :start_direction,
    :end_direction,
    :cs,
    :ce,
    :q1,
    :q3,
    :z1,
    :z2,
    :z3,
    :path_distance,
    :course,
    :start_speed,
    :end_speed,
    :start_radius,
    :end_radius,
    # :is_defined,
    :dubins
  ]

  # @spec new_config_point() :: struct()
  # def new_config_point() do
  #   %Navigation.Path.ConfigPoint{
  #     is_defined: false
  #   }
  # end

  @spec new(struct(), float()) :: struct()
  def new(waypoint, vehicle_turn_rate) do
    %Navigation.Path.ConfigPoint{
      pos: Navigation.Path.LatLonAlt.new(waypoint.latitude, waypoint.longitude, waypoint.altitude),
      start_speed: waypoint.speed,
      course: waypoint.course,
      start_radius: waypoint.speed/vehicle_turn_rate,
      dubins: Navigation.Path.DubinsPath.new()
    }
  end

  @spec print(struct()) :: struct()
  def print(cp) do
    # Logger.info(""
  end

end
