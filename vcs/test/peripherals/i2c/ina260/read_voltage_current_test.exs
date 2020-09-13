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
    config = Configuration.Module.Peripherals.I2c.get_ina260_config("power")
    Logger.info("config: #{inspect(config)}")
    # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
    Peripherals.I2c.Health.Ina260.Operator.start_link(config)
    Process.sleep(150000)
    [voltage, current, energy] = Health.Hardware.Battery.get_vie(battery)
    assert voltage > 7.3
    assert current < 3.0
  end
end
