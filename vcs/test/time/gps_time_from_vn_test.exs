defmodule Time.GpsTimeFromVnTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Time.System.start_link(Configuration.Module.Time.get_config(nil,nil))
    Peripherals.Uart.System.start_link(Configuration.Module.Peripherals.Uart.get_config(nil, :sim))
    Estimation.System.start_link(Configuration.Module.Estimation.get_config(nil, nil))
    Process.sleep(400)
    {:ok, []}
  end

  test "Set Server Time" do
    Logger.info("Set Server Time test")
    bodyaccel = %{x: 0, y: 0, z: 0}
    bodyrate = %{rollrate: 0, pitchrate: 0, yawrate: 0}
    attitude = %{roll: 0, pitch: 0, yaw: 1.0}
    velocity = %{north: 0, east: 0, down: 0}
    position = %{latitude: 0, longitude: 0, altitude: 0}

    Comms.System.start_operator(__MODULE__)
    Process.sleep(500)
    Peripherals.Uart.Estimation.VnIns.Operator.publish_vn_message(bodyaccel, bodyrate, attitude, velocity, position)
    # Set GPS Time Source
    Process.sleep(100)
    datetime_exp = DateTime.utc_now()
    datetime = Time.Server.get_gps_time_source()
    assert datetime.year == datetime_exp.year
    assert datetime.month == datetime_exp.month
    assert datetime.day == datetime_exp.day
    assert datetime.hour == datetime_exp.hour
    assert datetime.minute == datetime_exp.minute
    dt_sec = datetime.second
    Process.sleep(1000)
    current_time = Time.Server.get_time()
    assert current_time.second > dt_sec
    Process.sleep(11000)
  end
end
