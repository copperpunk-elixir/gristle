defmodule Display.Scenic.DisplayBatteryTest do
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
    config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(config)
    health_config = Configuration.Module.Health.get_config(model_type, node_type)
    Logger.info("config: #{inspect(health_config)}")
    Health.System.start_link(health_config)
    telem_config = Configuration.Module.Peripherals.Uart.get_telemetry_config(:Xbee)
    Peripherals.Uart.Telemetry.Operator.start_link(telem_config)
    {:ok, [vehicle_type: vehicle_type ]}
  end

  test "load gcs", context do
    Comms.System.start_operator(__MODULE__)
    Process.sleep(100)
    battery_type = :cluster
    battery_channel = 3
    voltage = 3.0
    current = 36.0
    dt = 1.0
    battery = Health.Hardware.Battery.new(battery_type, battery_channel)
    |> Health.Hardware.Battery.update_voltage(voltage)
    |> Health.Hardware.Battery.update_current(current, dt)
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:battery_status, battery}, self())
    Enum.reduce(1..10,battery, fn (x, battery) ->
      battery = Health.Hardware.Battery.update_voltage(battery, 1.5*x)
      |> Health.Hardware.Battery.update_current(current,1.0 )
      Logger.debug("voltage: #{Health.Hardware.Battery.get_value(battery, :voltage)}")
      Comms.Operator.send_global_msg_to_group(__MODULE__, {:battery_status, battery}, self())
      Process.sleep(1000)
      battery
    end)
  end
end
