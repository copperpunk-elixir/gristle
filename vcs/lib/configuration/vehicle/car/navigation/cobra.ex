defmodule Configuration.Vehicle.Car.Navigation.Cobra do
  require Logger

  @spec get_vehicle_limits() :: list()
  def get_vehicle_limits() do
    [
      vehicle_turn_rate: 1.0,
      vehicle_loiter_speed: 6,
      vehicle_agl_ground_threshold: 1000.0,
      vehicle_takeoff_speed: 1000,
    ]
  end
end
