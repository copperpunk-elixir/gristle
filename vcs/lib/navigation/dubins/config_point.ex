defmodule Navigation.Dubins.ConfigPoint do
  require Logger

  defstruct [
    :pos,
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
    :dubins,
    :goto_upon_completion
  ]

  @spec new(struct(), float()) :: struct()
  def new(waypoint, vehicle_turn_rate) do
    %Navigation.Dubins.ConfigPoint{
      pos: Navigation.Utils.LatLonAlt.new(waypoint.latitude, waypoint.longitude, waypoint.altitude),
      start_speed: waypoint.speed,
      course: waypoint.course,
      start_radius: waypoint.speed/vehicle_turn_rate,
      dubins: Navigation.Dubins.DubinsPath.new()
    }
  end
end
