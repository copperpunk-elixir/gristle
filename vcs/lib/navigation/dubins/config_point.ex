defmodule Navigation.Dubins.ConfigPoint do
  require Logger

  defstruct [
    :name,
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
    :goto_upon_completion,
    :type
  ]

  @spec new(struct(), float()) :: struct()
  def new(waypoint, vehicle_turn_rate) do
    radius = if (waypoint.speed < 0.5), do: 1000.0, else: waypoint.speed/vehicle_turn_rate
    # Logger.debug("new waypoint. speed/turn_rate/radius: #{waypoint.speed}/#{vehicle_turn_rate}/#{radius}")
    %Navigation.Dubins.ConfigPoint{
      name: waypoint.name,
      pos: Common.Utils.LatLonAlt.new(waypoint.latitude, waypoint.longitude, waypoint.altitude),
      start_speed: waypoint.speed,
      course: waypoint.course,
      start_radius: radius,
      dubins: Navigation.Dubins.DubinsPath.new(),
      type: waypoint.type
    }
  end

  @spec to_string(struct()) :: binary()
  def to_string(cp) do
    line1 = "cp #{inspect(cp.name)}: #{Common.Utils.LatLonAlt.to_string(cp.pos)}"
    line2 = "Speed/Course/Radius: #{Common.Utils.eftb(cp.start_speed, 1)}/#{Common.Utils.eftb_deg(cp.course,1)}/#{Common.Utils.eftb(cp.start_radius,1)}"
    line1 <> ", " <> line2
  end
end
