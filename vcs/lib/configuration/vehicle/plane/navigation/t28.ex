defmodule Configuration.Vehicle.Plane.Navigation.T28 do
  require Logger

  @spec get_vehicle_limits() :: list()
  def get_vehicle_limits() do
    [
      vehicle_turn_rate: 0.50,
      vehicle_loiter_speed: 12,
      vehicle_takeoff_speed: 15,
      vehicle_climb_speed: 15,
      vehicle_agl_ground_threshold: 3.0,
      vehicle_max_ground_speed: 10
    ]
  end
end
