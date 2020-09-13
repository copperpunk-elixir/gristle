defmodule Health.Hardware.Battery.BatteryIdTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Send Voltage/Current" do
    battery_type = :motor
    battery_channel = 1
    battery = Health.Hardware.Battery.new(battery_type, battery_channel)
    battery_id = Health.Hardware.Battery.get_battery_id(battery)
    assert battery_id == 33
    [type, channel] = Health.Hardware.Battery.get_type_channel_for_id(battery_id)
    assert type == battery_type
    assert channel == battery_channel

    battery_type = :cluster
    battery_channel = 11
    battery = Health.Hardware.Battery.new(battery_type, battery_channel)
    battery_id = Health.Hardware.Battery.get_battery_id(battery)
    assert battery_id == 11
    [type, channel] = Health.Hardware.Battery.get_type_channel_for_id(battery_id)
    assert type == battery_type
    assert channel == battery_channel

  end
end
