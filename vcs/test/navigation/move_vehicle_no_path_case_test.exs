defmodule Navigation.MoveVehicleNoPathCaseTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    Comms.System.start_operator(__MODULE__)

    Configuration.Module.start_modules([Estimation, Navigation], vehicle_type, node_type)
    # nav_config = Configuration.Module.Navigation.get_config(vehicle_type, nil)
    # Navigation.System.start_link(nav_config)
    Process.sleep(400)
    {:ok, []}
  end

  test "Move Vehicle Test", context do
    max_pos_delta = 0.00001
    max_vector_delta = 0.001
    max_rad_delta = 0.0001
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    # navigation_config = context[:config]
    current_mission = Navigation.Path.Mission.get_default_mission()
    Navigation.PathManager.load_mission(current_mission)

    Process.sleep(500)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    assert true
  end
end
