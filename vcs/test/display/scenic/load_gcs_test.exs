defmodule Display.Scenic.LoadGcsTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :gcs
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    # Need estimation and command
    config = Configuration.Vehicle.get_estimation_config(node_type)
    Estimation.System.start_link(config)
    # command_config = %{
    #   commander: %{vehicle_type: vehicle_type},
    #   frsky_rx: %{
    #     device_description: "Arduino Micro",
    #     publish_rx_output_loop_interval_ms: 100}
    # }
    command_config = Configuration.Vehicle.get_command_config(vehicle_type, node_type)
    Command.System.start_link(command_config)
    config = Configuration.Generic.get_display_config(vehicle_type)
    Display.Scenic.System.start_link(config)

    {:ok, [vehicle_type: vehicle_type ]}
  end

  test "load gcs", context do
    vehicle_type = context[:vehicle_type]
    Process.sleep(4000)
  end
end
