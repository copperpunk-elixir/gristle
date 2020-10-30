defmodule Peripherals.I2c.Sixfab.CalculateChecksumTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    # Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Calculate Checksum" do
    command = :get_battery_voltage
    # msg = Peripherals.I2c.Health.Sixfab.create_command(command_type)
    msg = 49..57
    checksum = Peripherals.I2c.Health.Sixfab.Operator.calculate_checksum(msg)
    Logger.debug("checksum: 0x#{Integer.to_string(checksum, 16)}")
    assert checksum == 0x31c3
    Process.sleep(200)
  end
end
