defmodule Configuration.Vehicle.Car.Navigation.FerrariF1 do
  require Logger

  @spec get_vehicle_limits() :: list()
  def get_vehicle_limits() do
    [
      vehicle_turn_rate: 0.5,
      vehicle_loiter_speed: 3,
      vehicle_agl_ground_threshold: 1000.0,
      vehicle_takeoff_speed: 1000,
    ]
  end
end
