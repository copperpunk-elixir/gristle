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

  @spec get_path_follower() :: list()
  def get_path_follower() do
    [
      k_path: 0.1,
      k_orbit: 2.0,
      chi_inf: 1.05,
      lookahead_dt: 1.0,
    ]
  end
end
