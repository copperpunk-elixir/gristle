defmodule Telemetry.BatteryMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Parse Message Test" do
    Logger.info("Parse Message Test")
    delta_float_max = 0.0001
    config = Configuration.Module.get_config(Telemetry, nil, nil)
    Peripherals.Uart.Telemetry.Operator.start_link(config.operator)
    ina260_config = Configuration.Module.Peripherals.I2c.get_ina260_config("power")
    Peripherals.I2c.Health.Ina260.Operator.start_link(ina260_config)
    Process.sleep(100000)
  end
end
