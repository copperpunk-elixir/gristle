defmodule Display.Scenic.LoadGcsTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    vehicle_config_module = Module.concat(Configuration.Vehicle, vehicle_type)
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Comms.Operator.start_link(%{name: __MODULE__})
    # Need estimation and command
    config = Configuration.Generic.get_estimator_config()
    Estimation.System.start_link(config)
    # command_config = %{
    #   commander: %{vehicle_type: vehicle_type},
    #   frsky_rx: %{
    #     device_description: "Arduino Micro",
    #     publish_rx_output_loop_interval_ms: 100}
    # }
    command_config = apply(Module.concat(vehicle_config_module, Command), :get_config, [])
    Command.System.start_link(command_config)
    {:ok, [vehicle_type: vehicle_type ]}
  end

  test "load gcs", context do
    vehicle_type = context[:vehicle_type]
    Display.Scenic.System.start_link(%{vehicle_type: vehicle_type})
    Process.sleep(1000000)
  end
end
