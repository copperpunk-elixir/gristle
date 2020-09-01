defmodule Pids.LevelIITest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "update PID-controller and check output" do
    vehicle_type = :Plane
    pid_config = Configuration.Vehicle.Plane.Pids.get_config()
    Pids.System.start_link(pid_config)
    scalar = pid_config.attitude_scalar
    max_delta = 0.00001
    op_name = :start_pid_test
    Comms.System.start_operator(op_name)
    Process.sleep(300)
    pv_cmd_map = %{roll: 0.2, pitch: -0.3, yaw: 0.1, thrust: 0.0}
    pv_value_map = %{attitude: %{roll: 0, pitch: 0, yaw: 0.123}, bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    airspeed = 10
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 2}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    output = Pids.Attitude.calculate_outputs(pv_cmd_map, pv_value_map.attitude, scalar)
    exp_roll_rr_output = scalar.roll_rollrate.scale*(pv_cmd_map.roll - pv_value_map.attitude.roll)
    Logger.debug("rr: #{output.rollrate}")
    exp_pitch_pr_output = scalar.pitch_pitchrate.scale*(pv_cmd_map.pitch - pv_value_map.attitude.pitch)
    Logger.debug("pr: #{output.pitchrate}")
    exp_yaw_yr_output = scalar.yaw_yawrate.scale*(pv_cmd_map.yaw - 0)
    Logger.debug("yr: #{output.yawrate}")
    assert_in_delta(output.rollrate, exp_roll_rr_output, max_delta)
    assert_in_delta(output.pitchrate, exp_pitch_pr_output, max_delta)
    assert_in_delta(output.yawrate, exp_yaw_yr_output, max_delta)
    # Remove Yaw, so it is calculated by according to roll/pitch
    pv_cmd_map = %{roll: 0.2, pitch: -0.3, thrust: 0.0}
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 2}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    output = Pids.Attitude.calculate_outputs(pv_cmd_map, pv_value_map.attitude, scalar)
    exp_yaw_yr_output = pv_cmd_map.roll*0.1
    Logger.debug("yr: #{output.yawrate}")
    assert_in_delta(output.yawrate, exp_yaw_yr_output, max_delta)
  end

end
