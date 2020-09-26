defmodule Display.Scenic.SaveLogTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    vehicle_type = :Plane
    model_type = :Cessna
    node_type = :all
    Comms.System.start_link()
    Time.Server.start_link(Configuration.Module.Time.get_server_config())
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    # Need estimation and command
    config = Configuration.Module.get_config(Display.Scenic, model_type, node_type)
    Display.Scenic.System.start_link(config)
    telem_config = Configuration.Module.Peripherals.Uart.get_telemetry_config(:Xbee)
    Peripherals.Uart.Telemetry.Operator.start_link(telem_config)
    log_config = Configuration.Module.Logging.get_config(nil,nil)
    Logging.Logger.start_link(log_config.logger)

    {:ok, [vehicle_type: vehicle_type ]}
  end

  test "load gcs", context do
    Comms.System.start_operator(__MODULE__)
    Process.sleep(100000)
  end
end
