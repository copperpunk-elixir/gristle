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
    attitude = %{}
    bodyrate = %{rollrate: 0.1, pitchrate: 0.0, yawrate: -3.0}
    body_accel = %{x: 0.0, y: 0.0, z: 9.8}
    pv_measured = %{attitude: attitude, bodyrate: bodyrate, body_accel: body_accel, position: position, velocity: velocity}
    Enum.each(1..1000, fn x ->
      position = %{latitude: position.latitude + x/10000,
                   longitude: position.longitude - x/5000,
                   altitude: position.altitude*(1 + x/100)
                  }
      velocity = %{north: velocity.north + x/10,
                   east: velocity.east - x/100,
                   down: velocity.down*(1 + x/100)
                  }
      body_accel = %{body_accel | y: body_accel.y + x/1000, z: body_accel.z - x/1000}
      pv_measured = %{pv_measured | body_accel: body_accel, position: position, velocity: velocity}
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:pv_measured, pv_measured}, :pv_measured, self())
      Process.sleep(10)
    end)
    Process.sleep(200000)
  end
end