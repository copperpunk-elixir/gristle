defmodule Display.Scenic.LoadGcsTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    # Need estimation and command
    config = Configuration.Module.get_config(Estimation, vehicle_type,node_type)
    Estimation.System.start_link(config)
    # command_config = %{
    #   commander: %{vehicle_type: vehicle_type},
    #   frsky_rx: %{
    #     device_description: "Arduino Micro",
    #     publish_rx_output_loop_interval_ms: 100}
    # }
    command_config = Configuration.Module.get_config(Command, vehicle_type, node_type)
    Command.System.start_link(command_config)
    config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(config)

    {:ok, [vehicle_type: vehicle_type ]}
  end

  test "load gcs", context do
    vehicle_type = context[:vehicle_type]
    Process.sleep(4000)
  end
end
