defmodule Peripherals.I2c.TerarangerEvo.ReadRangeTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Boss.System.common_prepare()
    {:ok, []}
  end

 test "Read Atto89 Voltage/Current" do
   config = Configuration.Module.Peripherals.I2c.get_teraranger_config()
   Logger.info("config: #{inspect(config)}")
   # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
   Peripherals.I2c.Estimation.TerarangerEvo.Operator.start_link(config)
   Process.sleep(100)
   Peripherals.I2c.Estimation.TerarangerEvo.Operator.request_read_range()
   Process.sleep(100)
   range = Peripherals.I2c.Estimation.TerarangerEvo.Operator.get_range()
   assert range > 0
   assert range < 65
 end
end
