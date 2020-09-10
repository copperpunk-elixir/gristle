defmodule Health.SendVoltageCurrentTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    model_type = :Cessna
    node_type = :all
    health_config = Configuration.Module.Health.get_config(model_type, node_type)
    Logger.info("config: #{inspect(health_config)}")
    Health.System.start_link(health_config)
    telem_config = Configuration.Module.Peripherals.Uart.get_telemetry_config(:Xbee)
    # Peripherals.Uart.Telemetry.Operator.start_link(telem_config)
    {:ok, []}
  end

  test "Send Voltage/Current" do
    Comms.System.start_operator(__MODULE__)
    Process.sleep(100)
    # Ina260 should publish battery information to those who want it
    battery = Health.Monitor.get_battery(:motor)
    voltage = Health.Hardware.Battery.get_value(battery, :voltage)
    Process.sleep(100)
    assert is_float(voltage)
    assert voltage > 10.0
  end
end
