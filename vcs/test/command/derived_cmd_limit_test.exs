defmodule Command.DerivedCmdLimitTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Car
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    navigation_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Navigation)
    Navigation.System.start_link(navigation_config)
    command_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Command)
    Command.System.start_link(command_config)
    Process.sleep(300)
    {:ok, [vehicle_type: vehicle_type]}
  end
  test "Get Commander output limits from PID limits" do
    Logger.info("Put TX into Control State 1")
    Logger.info("Put yaw to max limit")
    Process.sleep(3000)
    Comms.TestMemberAllGroups.start_link()
    Process.sleep(500)
    goals = Comms.TestMemberAllGroups.get_goals(1)
    Logger.info("goals: #{inspect(goals)}")
    Process.sleep(100)
    assert goals.yawrate == Enum.at(Map.get(Configuration.Vehicle.Car.Command.get_rx_output_channel_map,1),1) |> elem(4)
  end
end



