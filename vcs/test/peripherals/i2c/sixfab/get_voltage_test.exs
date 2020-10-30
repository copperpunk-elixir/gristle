defmodule Peripherals.I2c.Sixfab.GetVoltageTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Read Voltage/Current" do
    config = Configuration.Module.Peripherals.I2c.get_sixfab_config("cluster", 0)
    Logger.info("config: #{inspect(config)}")
    # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
    Peripherals.I2c.Health.Sixfab.Operator.start_link(config)
    Process.sleep(150000)
  end
end
