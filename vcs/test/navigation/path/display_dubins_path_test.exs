defmodule Navigation.DisplayDubinsPathTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    Comms.System.start_operator(__MODULE__)
    nav_config = Configuration.Module.get_config(Navigation, vehicle_type, :all)
    # Navigation.PathManager.start_link(nav_config.path_manager)
    config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(config)
    Process.sleep(400)
    {:ok, [config: nav_config.path_manager]}
  end

  test "Display Dubins Test", context do
    max_pos_delta = 0.00001
    max_vector_delta = 0.001
    max_rad_delta = 0.0001
    path_manager_config = context[:config]

    seatac_mission = Navigation.Path.Mission.get_seatac_mission()
    starting_wp = seatac_mission.waypoints |> Enum.at(0)

    Enum.each(1..10000, fn _x ->
      loop = if (:rand.uniform(2) == 1), do: true, else: false
      current_mission = Navigation.Path.Mission.get_random_mission(starting_wp, :rand.uniform(4)*0 + 4, false)
      Navigation.PathManager.load_mission(current_mission, __MODULE__)
      Process.sleep(200)
      IO.gets "ready for next mission?"
    end)
    # config_points = Navigation.PathManager.get_config_points()
    # wp1 = Enum.at(current_mission.waypoints,0)
    # dubins = Navigation.PathManager.get_dubins_for_cp(0)

    Process.sleep(100000)
  end
end
