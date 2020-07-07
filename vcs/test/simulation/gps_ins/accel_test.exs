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
    Simulation.XplaneReceive.start_link(receive_config)
    Simulation.XplaneSend.start_link(send_config)
    Process.sleep(100)
    {:ok, []}
  end

  test "Spoof Accel", context do
    # Create Attitude Message
    attitude_deg = %{roll: 5.0, pitch: 10.0, yaw: -15.0}
    body_rate_deg = %{rollrate: -45.0, pitchrate: 90.0, yawrate: -180.0}
    body_rate_rad = Common.Utils.map_deg2rad(body_rate_deg)
    Simulation.XplaneSend.send_message(:attitude, attitude_deg)
    Simulation.XplaneSend.send_message(:bodyrate, body_rate_rad)
    Process.sleep(200000)
  end
end
