defmodule Time.GpsTimeFromVnTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    vehicle_type = :Plane
    node_type = :sim
    modules = [Estimation, Time, Peripherals.Uart, Logging]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)

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
    Process.sleep(100)
    # The clock should not have been updated yet
    Logging.Logger.save_log()
    Process.sleep(11000)
    # Now the clock should have been updated
    # Check for a file saved at this time
    Logging.Logger.save_log()
    Process.sleep(100)
  end
end
