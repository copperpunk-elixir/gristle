defmodule Peripherals.I2c.Sixfab.CreateCommandTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    # Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Create Command" do
    command = :get_battery_voltage
    msg = Peripherals.I2c.Health.Sixfab.Operator.create_command(command)
    Logger.info("#{inspect(msg)}")
    # assert checksum == 0x31c3
    msg = [1,2,3,4,5,6,7,8,9,10,11]
    voltage_list = Enum.slice(msg, 5, 4)
    Logger.debug("voltage List: #{inspect(voltage_list)}")
    value = Peripherals.I2c.Health.Sixfab.Operator.convert_result_to_integer(voltage_list, 4)
    <<exp_value::32>> = <<6,7,8,9>>
    assert value == exp_value
    Process.sleep(200)
  end
end
