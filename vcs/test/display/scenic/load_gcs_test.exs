defmodule Display.Scenic.LoadGcsTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Comms.Operator.start_link(%{name: __MODULE__})
    # Need estimation and command
    config = Configuration.Generic.get_estimator_config()
    Estimation.System.start_link(config)
    command_config = %{
      commander: %{vehicle_type: :Plane},
      frsky_rx: %{
        device_description: "Arduino Micro",
        publish_rx_output_loop_interval_ms: 100}
    }
    Command.System.start_link(command_config)
    {:ok, []}
  end

  test "load gcs" do
    Display.Scenic.System.start_link(%{vehicle_type: :Plane})
    Process.sleep(10000)
  end
end
