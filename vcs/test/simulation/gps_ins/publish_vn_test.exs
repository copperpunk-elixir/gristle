defmodule Simulation.Ublox.SendImuMsgTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    Logger.info("Spoof Accel Test")
    config = Configuration.Module.Peripherals.Uart.get_vn_ins_config(:sim)
    Peripherals.Uart.Estimation.VnIns.Operator.start_link(config)
    Process.sleep(400)
    {:ok, []}
  end

  test "Send VN msg" do
    body_accel = %{x: 0.0, y: 0.1, z: 0.2}
    bodyrate = %{rollrate: -0.1, pitchrate: 0.2, yawrate: 0.3}
    attitude = %{roll: 0.123, pitch: -0.234, yaw: 0.345}
    velocity = %{north: 3.4, east: -4.5, down: 5.6}
    position = %{latitude: 0.80, longitude: 2.1, altitude: 123.45}
    Peripherals.Uart.Estimation.VnIns.Operator.publish_vn_message(body_accel, bodyrate, attitude, velocity, position)
    Process.sleep(100)
  end
end

