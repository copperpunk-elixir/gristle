defmodule Command.GetGoalsFromRxTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    {:ok, []}
  end

  # test "Get Channel 0 from FrSky interface" do
  #   Command.System.start_link(%{commander: %{vehicle_type: :Plane}})
  #   Process.sleep(4000)
  # end

  # This test is only required if something changes with the FrSky receiver
  # test "Show Cmds sent out as Goals" do
  #   navigator_config = %{vehicle_type: :Plane, navigator_loop_interval_ms: 1000}
  #   Navigation.System.start_link(%{navigator: navigator_config})

  #   command_config = %{
  #     commander: %{vehicle_type: :Plane},
  #     frsky_rx: %{publish_rx_output_loop_interval_ms: 1000}
  #   }
  #   Command.System.start_link(command_config)
  #   Process.sleep(4000)

  # end
end
