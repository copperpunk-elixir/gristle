defmodule Configuration.Vehicle.Plane.Navigation.Cessna do
  require Logger

  @spec get_vehicle_limits() :: list()
  def get_vehicle_limits() do
    [
      vehicle_turn_rate: 0.08,
      vehicle_loiter_speed: 40,
      vehicle_takeoff_speed: 40,
      vehicle_climb_speed: 50,
      vehicle_agl_ground_threshold: 3.0,
      vehicle_max_ground_speed: 35
    ]
  end
end
