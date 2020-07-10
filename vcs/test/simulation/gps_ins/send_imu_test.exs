defmodule Simulation.GpsIns.AccelTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    Logger.info("Spoof Accel Test")
    receive_config = Configuration.Module.Simulation.get_simulation_xplane_receive_config()
    send_config = Configuration.Module.Simulation.get_simulation_xplane_send_config(vehicle_type)
    |> Map.put(:dest_port, receive_config.port)
    cp_ins_config = Configuration.Module.Estimation.get_cp_ins_config()
    Simulation.XplaneReceive.start_link(receive_config)
    Simulation.XplaneSend.start_link(send_config)
    Peripherals.Uart.CpIns.start_link(cp_ins_config)
    Process.sleep(400)
    {:ok, []}
  end

  test "Spoof Accel", context do
    # Create Attitude Message
    attitude_deg = %{roll: 45.0, pitch: 0.0, yaw: -15.0}
    body_rate_deg = %{rollrate: -45.0, pitchrate: 90.0, yawrate: -180.0}
    body_rate_rad = Common.Utils.map_deg2rad(body_rate_deg)
   bodyaccel = %{x: 0.01, y: 0.005, z: 1.05}
    position = %{latitude: Common.Utils.Math.deg2rad(45.0), longitude: Common.Utils.Math.deg2rad(-120.0), altitude: 123.4}
    velocity = %{north: 10.0, east: -1.0, down: 0.5}
    Simulation.XplaneSend.send_message(:attitude, attitude_deg)
    Simulation.XplaneSend.send_message(:bodyrate, body_rate_rad)
    Simulation.XplaneSend.send_message(:bodyaccel, bodyaccel)
    Simulation.XplaneSend.send_message(:position, position)
    Simulation.XplaneSend.send_message(:velocity, velocity)
    Process.sleep(200000)
  end
end
