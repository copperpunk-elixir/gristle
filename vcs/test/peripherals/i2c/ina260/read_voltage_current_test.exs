defmodule Peripherals.I2c.Ina260.ReadVoltageCurrentTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Read Voltage/Current" do
    config = Configuration.Module.Peripherals.I2c.get_config(nil, nil)
    Logger.info("config: #{inspect(config)}")
    Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
    Process.sleep(1500)
    voltage = Peripherals.I2c.Health.Ina260.Operator.get_voltage()
    assert voltage > 7.3
    current = Peripherals.I2c.Health.Ina260.Operator.get_current()
    assert current < 3.0
  end
end
