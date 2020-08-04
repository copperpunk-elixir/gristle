defmodule Telemetry.ParseMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Parse Message Test" do
    delta_float_max = 0.0001
    config = Configuration.Module.get_config(Telemetry, nil, nil)
    {:ok, pid} = Telemetry.Operator.start_link(config.operator)

    accel = %{x: 1, y: 2, z: 3}
    gyro = %{x: -1, y: -2, z: -3}

    now = DateTime.utc_now
    {now_us, _} = now.microsecond
    iTOW = Telemetry.Ublox.get_itow()
    nano = now_us*1000
    bytes = [-4,-4,4,4,4,4,4,4]
    message_values = [iTOW, nano, accel.x, accel.y, accel.z, gyro.x, gyro.y, gyro.z]
    accel_gyro = Telemetry.Ublox.construct_message(1,0x69, message_values, bytes)
    accel_gyro_payload = :binary.bin_to_list(accel_gyro) |> Enum.drop(6) |> Enum.drop(-2)
    [_itow, _nano, ax, ay, az, gx, gy, gz] = Telemetry.Ublox.deconstruct_message(accel_gyro_payload,bytes)
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

  # test ""
end
