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

  test "Move Vehicle Test", context do
    max_pos_delta = 0.00001
    max_vector_delta = 0.001
    max_rad_delta = 0.0001
    path_manager_config = context[:config]

    current_mission = Navigation.Path.Mission.get_seatac_mission()
    Navigation.PathManager.load_mission(current_mission, __MODULE__)
    Process.sleep(100)
    # config_points = Navigation.PathManager.get_config_points()
    # wp1 = Enum.at(current_mission.waypoints,0)
    # dubins = Navigation.PathManager.get_dubins_for_cp(0)

    Process.sleep(100000)
  end
end
