defmodule Configuration.Vehicle.Multirotor.Navigation.QuadX do
  require Logger

  @spec get_vehicle_limits() :: list()
  def get_vehicle_limits() do
    [
      vehicle_turn_rate: 1.5,
      vehicle_loiter_speed: 6,
      vehicle_takeoff_speed: 0,
      vehicle_climb_speed: 2,
      vehicle_agl_ground_threshold: 3.0,
      vehicle_max_ground_speed: 0.5
    ]
  end
end
