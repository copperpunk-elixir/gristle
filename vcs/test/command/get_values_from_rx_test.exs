defmodule Command.GetValuesFromRxTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    navigation_config = Configuration.Module.get_config(Navigation, vehicle_type, node_type)
    Navigation.System.start_link(navigation_config)
    command_config = Configuration.Module.get_config(Command, vehicle_type, node_type)
    Logger.info("Command config: #{inspect(command_config)}")
    Command.System.start_link(command_config)
    Process.sleep(300)
    {:ok, [vehicle_type: vehicle_type]}
  end

  # test "Get Channel 0 from FrSky interface" do
  #   Command.System.start_link(%{commander: %{vehicle_type: :Plane}})
  #   Process.sleep(4000)
  # end

  # # This test is only required if something changes with the FrSky receiver
  # test "Show Plane Cmds sent out as Goals" do

  #   command_config = %{
  #     commander: %{vehicle_type: :Plane},
  #     frsky_rx: %{
  #       device_description: "Feather"
  #     }
  #   }
  #   Command.System.start_link(command_config)
  #   Process.sleep(400000)
  # end

  # test "Show Car Cmds sent out as Goals", context do
  #   Process.sleep(400000)
  # end
end
