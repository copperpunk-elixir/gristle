defmodule Health.Hardware.Battery.SendVoltageCurrentTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Comms.System.start_link()
    Time.Server.start_link(Configuration.Module.Time.get_server_config())
    Process.sleep(100)
    model_type = :Cessna
    node_type = :all
    health_config = Configuration.Module.Health.get_config(model_type, node_type)
    Logger.info("config: #{inspect(health_config)}")
    Health.System.start_link(health_config)
    telem_config = Configuration.Module.Peripherals.Uart.get_telemetry_config(:Xbee)
    Peripherals.Uart.Telemetry.Operator.start_link(telem_config)
    {:ok, []}
  end

  test "Store battery status" do
    Comms.System.start_operator(__MODULE__)
    Process.sleep(100)
    battery_type = :cluster
    battery_channel = 3
    voltage = 3.0
    current = 0.5
    dt = 1.0
    battery = Health.Hardware.Battery.new(battery_type, battery_channel)
    |> Health.Hardware.Battery.update_voltage(voltage)
    |> Health.Hardware.Battery.update_current(current, dt)
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:battery_status, battery}, self())

    Process.sleep(2000)
  end

end
