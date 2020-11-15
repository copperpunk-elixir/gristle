defmodule Peripherals.I2c.Battery.ReadVoltageCurrentTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Boss.System.common_prepare()
    {:ok, []}
  end

  # test "Read Atto90 Voltage/Current" do
  #   device = "Atto90"
  #   battery_type = "cluster"
  #   battery_channel = 0
  #   config = Configuration.Module.Peripherals.I2c.get_battery_config(String.to_atom(device), battery_type, battery_channel)
  #   Logger.info("config: #{inspect(config)}")
  #   # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
  #   Peripherals.I2c.Health.Battery.Operator.start_link(config)
  #   Process.sleep(100)
  #   Peripherals.I2c.Health.Battery.Operator.request_read_voltage(battery_type, battery_channel)
  #   Process.sleep(50)
  #   Peripherals.I2c.Health.Battery.Operator.request_read_current(battery_type, battery_channel)

  #   Process.sleep(200)
  #   battery = Peripherals.I2c.Health.Battery.Operator.get_battery(battery_type, battery_channel)
  #   assert battery.voltage_V > 1.0
  #   assert battery.current_A > 1.0
  # end

  # test "Read Ina219 Voltage/Current" do
  #   device = "Ina219"
  #   battery_type = "motor"
  #   battery_channel = 0
  #   config = Configuration.Module.Peripherals.I2c.get_battery_config(String.to_atom(device), battery_type, battery_channel)
  #   Logger.info("config: #{inspect(config)}")
  #   # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
  #   Peripherals.I2c.Health.Battery.Operator.start_link(config)
  #   Process.sleep(100)
  #   Peripherals.I2c.Health.Battery.Operator.request_read_voltage(battery_type, battery_channel)
  #   Process.sleep(50)
  #   Peripherals.I2c.Health.Battery.Operator.request_read_current(battery_type, battery_channel)

  #   Process.sleep(200)
  #   battery = Peripherals.I2c.Health.Battery.Operator.get_battery(battery_type, battery_channel)
  #   assert battery.voltage_V > 1.0
  #   assert battery.current_A > 1.0
  # end

  # test "Read Ina260 Voltage/Current" do
  #   device = "Ina260"
  #   battery_type = "motor"
  #   battery_channel = 1
  #   config = Configuration.Module.Peripherals.I2c.get_battery_config(String.to_atom(device), battery_type, battery_channel)
  #   Logger.info("config: #{inspect(config)}")
  #   # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
  #   Peripherals.I2c.Health.Battery.Operator.start_link(config)
  #   Process.sleep(100)
  #   Peripherals.I2c.Health.Battery.Operator.request_read_voltage(battery_type, battery_channel)
  #   Process.sleep(50)
  #   Peripherals.I2c.Health.Battery.Operator.request_read_current(battery_type, battery_channel)

  #   Process.sleep(200)
  #   battery = Peripherals.I2c.Health.Battery.Operator.get_battery(battery_type, battery_channel)
  #   assert battery.voltage_V > 1.0
  #   assert battery.current_A > 1.0
  # end

  test "Read Sixfab Voltage/Current" do
    device = "Sixfab"
    battery_type = "cluster"
    battery_channel = 1
    config = Configuration.Module.Peripherals.I2c.get_battery_config(String.to_atom(device), battery_type, battery_channel)
    Logger.info("config: #{inspect(config)}")
    # Peripherals.I2c.Health.Ina260.Operator.start_link(Map.get(config, Health.Ina260))
    Peripherals.I2c.Health.Battery.Operator.start_link(config)
    Process.sleep(100)
    Peripherals.I2c.Health.Battery.Operator.request_read_voltage(battery_type, battery_channel)
    Process.sleep(50)
    Peripherals.I2c.Health.Battery.Operator.request_read_current(battery_type, battery_channel)

    Process.sleep(200)
    battery = Peripherals.I2c.Health.Battery.Operator.get_battery(battery_type, battery_channel)
    assert battery.voltage_V > 1.0
    assert battery.current_A > 1.0
  end

end
