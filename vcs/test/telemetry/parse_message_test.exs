defmodule Telemetry.ParseMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Parse Message Test" do
    Logger.info("Parse Message Test")
    delta_float_max = 0.0001
    config = Configuration.Module.get_config(Telemetry, nil, nil)
    {:ok, pid} = Telemetry.Operator.start_link(config.operator)

    accel = %{x: 1, y: 2, z: 3}
    gyro = %{x: -1, y: -2, z: -3}

    now = DateTime.utc_now
    {now_us, _} = now.microsecond
    iTOW = Telemetry.Ublox.get_itow(now)
    nano = now_us*1000
    message_values = [iTOW, nano, accel.x, accel.y, accel.z, gyro.x, gyro.y, gyro.z]
    accel_gyro = Telemetry.Ublox.construct_message(:accel_gyro, message_values)
    accel_gyro_payload = :binary.bin_to_list(accel_gyro) |> Enum.drop(6) |> Enum.drop(-2)
    [_itow, _nano, ax, ay, az, gx, gy, gz] = Telemetry.Ublox.deconstruct_message(:accel_gyro, accel_gyro_payload)
    assert_in_delta(ax, accel.x, delta_float_max)
    assert_in_delta(ay, accel.y, delta_float_max)
    assert_in_delta(az, accel.z, delta_float_max)
    send(pid,{:circuits_uart, 0,accel_gyro})
    Process.sleep(500)
    accel_gyro = Telemetry.Operator.get_accel_gyro()
    accel_telem = accel_gyro.accel
    gyro_telem = accel_gyro.bodyrate
    assert_in_delta(accel_telem.x, accel.x, delta_float_max)
    assert_in_delta(accel_telem.y, accel.y, delta_float_max)
    assert_in_delta(accel_telem.z, accel.z, delta_float_max)

  end

  test "Send Message Test" do
    Logger.info("Send Message Test")
    Process.sleep(500)
    config = Configuration.Module.get_config(Telemetry, nil, nil)
    {:ok, pid} = Telemetry.Operator.start_link(config.operator)
    Process.sleep(100)
    position = %{latitude: 12, longitude: 34, altitude: 56.7}
    velocity = %{speed: 50, course: 0.23}
    attitude = %{roll: 0.1, pitch: -0.2, yaw: 1.23}
    now = DateTime.utc_now
    {now_us, _} = now.microsecond
    iTOW = Telemetry.Ublox.get_itow(now)
    nano = now_us*1000
    bytes = Telemetry.Ublox.get_bytes_for_class_and_id(0x45, 0x01)
    message_values = [iTOW, nano, position.latitude, position.longitude, position.altitude, velocity.speed, velocity.course, attitude.roll, attitude. pitch, attitude.yaw]
    pvat = Telemetry.Ublox.construct_message(0x45,0x01, message_values, bytes)
    Logger.debug("message: #{inspect(pvat)}")
    Telemetry.Operator.send_message(pvat)
    send(pid,{:circuits_uart, 0,pvat})
    send(pid,{:circuits_uart, 0,<<1,2,3,4,5>>})
    send(pid,{:circuits_uart, 0,pvat})
    Process.sleep(1000)
    assert true
  end
end
