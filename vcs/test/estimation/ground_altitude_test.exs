defmodule Estimation.GroundAltitudeTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    vehicle_type = :Plane
    Comms.System.start_link()
    Process.sleep(100)
    config = Configuration.Module.get_config(Estimation, vehicle_type, :all)
    Estimation.Estimator.start_link(config.estimator)
    Process.sleep(500)
    {:ok, []}
  end

  test "Ground Altitude Test" do
    Comms.System.start_operator(__MODULE__)
    Process.sleep(200)
    Logger.info("Ground Altitude Test")
    altitude = 100.0
    position = %{latitude: 0, longitude: 0, altitude: altitude}
    velocity = %{north: 1.0, east: 2.0, down: 0}
    pos_vel = %{position: position, velocity: velocity}
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, pos_vel}, self())
    Process.sleep(200)
    agl = Estimation.Estimator.get_value(:agl)
    ground_alt = Estimation.Estimator.get_value(:ground_altitude)
    # No valid AGL measurement, so ground_altitude = 0, and AGL = altitude - ground_alt
    assert agl == altitude
    assert ground_alt == 0

    measured_agl = 30
    Enum.each(1..10, fn _i ->
      Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_measured, :range}, measured_agl}, self())
      Process.sleep(100)
    end)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, pos_vel}, self())
    Process.sleep(20)
    agl = Estimation.Estimator.get_value(:agl)
    ground_alt = Estimation.Estimator.get_value(:ground_altitude)
    # Valid AGL, so AGL should = measured_agl
    # Ground_alt is now (altitude - AGL)
    assert agl == measured_agl
    assert ground_alt == altitude - measured_agl

    new_alt = 150.0
    pos_vel = put_in(pos_vel, [:position, :altitude], new_alt)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, pos_vel}, self())
    Process.sleep(20)
    agl = Estimation.Estimator.get_value(:agl)
    ground_alt = Estimation.Estimator.get_value(:ground_altitude)
    # Still valid AGL, but only the altitude has changed
    # So the AGL still = measured_agl
    # And thus the ground_alt will have changed along with the new_alt
    assert agl == measured_agl
    assert ground_alt == new_alt - measured_agl

    # Allow the AGL watchdog to expire
    Process.sleep(500)
    new_alt = 200.0
    pos_vel = put_in(pos_vel, [:position, :altitude], new_alt)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, pos_vel}, self())
    Process.sleep(100)
    agl = Estimation.Estimator.get_value(:agl)
    ground_alt_new = Estimation.Estimator.get_value(:ground_altitude)
    # Now the AGL should be measured between the altitude and ground_altitude
    # And the ground_alt should not have changed since the last udpate
    assert agl == new_alt-ground_alt
    assert ground_alt == ground_alt_new
    end
  end
