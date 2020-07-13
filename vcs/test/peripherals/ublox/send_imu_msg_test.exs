defmodule Simulation.Ublox.SendImuMsgTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    Logger.info("Spoof Accel Test")
    cp_ins_config = Configuration.Module.Estimation.get_cp_ins_config()
    Peripherals.Uart.CpIns.start_link(cp_ins_config)
    Process.sleep(400)
    {:ok, []}
  end

  test "Spoof Accel", context do
    # Create Attitude Message
    position = %{latitude: Common.Utils.Math.deg2rad(45.0), longitude: Common.Utils.Math.deg2rad(-120.0), altitude: 123.4}
    velocity = %{north: 10.0, east: -1.0, down: 0.5}
    attitude = %{roll: 0.0, pitch: 0.0, yaw: 0.0}
    bodyrate = %{rollrate: Common.Utils.Math.deg2rad(5.0), pitchrate: 0.0, yawrate: 0.0}
    bodyaccel = %{x: 0.0, y: 0.173648178*Common.Constants.gravity(), z: 0.984807753*Common.Constants.gravity()}
    pv_measured = %{attitude: attitude, bodyrate: bodyrate, bodyaccel: bodyaccel, position: position, velocity: velocity}
    Enum.each(1..1000, fn x ->
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:pv_measured, pv_measured}, :pv_measured, self())
      Process.sleep(10)
    end)
    Process.sleep(200000)
  end
end
