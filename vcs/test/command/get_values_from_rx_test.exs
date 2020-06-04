defmodule Command.GetGoalsFromRxTest do
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

    {:ok, [vehicle_type: vehicle_type]}
  end

  # test "Get Channel 0 from FrSky interface" do
  #   Command.System.start_link(%{commander: %{vehicle_type: :Plane}})
  #   Process.sleep(4000)
  # end

  # This test is only required if something changes with the FrSky receiver
  # test "Show Plane Cmds sent out as Goals" do
  #   navigator_config = %{vehicle_type: :Plane, navigator_loop_interval_ms: 100}
  #   Navigation.System.start_link(%{navigator: navigator_config})

  #   command_config = %{
  #     commander: %{vehicle_type: :Plane},
  #     frsky_rx: %{
  #       device_description: "Arduino Micro",
  #       publish_rx_output_loop_interval_ms: 100}
  #   }
  #   Command.System.start_link(command_config)
  #   Process.sleep(4000)
  # end

  test "Show Car Cmds sent out as Goals", context do
    Process.sleep(4000)
  end
end
