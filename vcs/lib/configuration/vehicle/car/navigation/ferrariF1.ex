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

  @spec get_path_follower() :: list()
  def get_path_follower() do
    [
      k_path: 0.125,
      k_orbit: 1.0,
      chi_inf: 1.57,
      lookahead_dt: 1.0,
    ]
  end
end
