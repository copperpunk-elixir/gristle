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
    {:ok, []}
  end

  test "Display Dubins Test" do

    seatac_mission = Navigation.Path.Mission.get_seatac_mission()
    starting_wp = seatac_mission.waypoints |> Enum.at(0)

    Enum.each(1..10000, fn _x ->
      loop = if (:rand.uniform(2) == 1), do: true, else: false
      current_mission = Navigation.Path.Mission.get_random_mission(starting_wp, :rand.uniform(4) + 4, loop)
      Navigation.PathManager.load_mission(current_mission, __MODULE__)
      Process.sleep(200)
      IO.gets "ready for next mission?"
    end)
    # Process.sleep(100000)
  end
end
