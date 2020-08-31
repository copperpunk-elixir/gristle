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
    pid_config = %{
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
    pids = Configuration.Vehicle.Plane.Pids.Cessna.get_pids()
    pid_config = Map.merge(pid_config, %{pids: pids})
    Pids.System.start_link(pid_config)

    max_delta = 0.00001
    op_name = :start_pid_test
    aileron_pid = pid_config.pids.rollrate.aileron
    Comms.System.start_operator(op_name)
    Process.sleep(300)
    pv_cmd_map = %{roll: 0.2, pitch: -0.3, yaw: 0.1, thrust: 0.0}
    pv_value_map = %{attitude: %{roll: 0, pitch: 0, yaw: 0.123}, bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    airspeed = 10
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 2}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    roll_rollrate_output = Pids.Pid.get_output(:roll, :rollrate)
    exp_roll_rr_output = pids.roll.rollrate.kp*(pv_cmd_map.roll - pv_value_map.attitude.roll)
    Logger.debug("rr: #{roll_rollrate_output}")
    pitch_pitchrate_output = Pids.Pid.get_output(:pitch, :pitchrate)
    exp_pitch_pr_output = pids.pitch.pitchrate.kp*(pv_cmd_map.pitch - pv_value_map.attitude.pitch)
    Logger.debug("pr: #{pitch_pitchrate_output}")
    yaw_yr_output = Pids.Pid.get_output(:yaw, :yawrate)
    exp_yaw_yr_output = pids.yaw.yawrate.kp*(pv_cmd_map.yaw - 0)
    Logger.debug("yr: #{yaw_yr_output}")
    assert_in_delta(roll_rollrate_output, exp_roll_rr_output, max_delta)
    assert_in_delta(pitch_pitchrate_output, exp_pitch_pr_output, max_delta)
    assert_in_delta(yaw_yr_output, exp_yaw_yr_output, max_delta)
    # Remove Yaw, so it is calculated by according to roll/pitch
    pv_cmd_map = %{roll: 0.2, pitch: -0.3, thrust: 0.0}
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 2}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    yaw_yr_output = Pids.Pid.get_output(:yaw, :yawrate)
    exp_yaw_yr_output = pv_cmd_map.roll*0.1
    Logger.debug("yr: #{yaw_yr_output}")
    assert_in_delta(yaw_yr_output, exp_yaw_yr_output, max_delta)
    # exp_rollrate_aileron_output =
    #   aileron_pid.kp*rollrate_corr + aileron_pid.ki*rollrate_corr*dt + aileron_pid.ff.(pv_cmd_map.rollrate, pv_value_map.bodyrate.rollrate,airspeed) + aileron_pid.output_neutral
    #   |> Common.Utils.Math.constrain(0, 1)
    # rollrate_corr_prev = rollrate_corr
    # # Another cycle
    # rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
    # Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    # Process.sleep(100)
    # exp_rollrate_aileron_output =
    #   aileron_pid.kp*rollrate_corr + aileron_pid.ki*(rollrate_corr+rollrate_corr_prev)*dt + aileron_pid.ff.(pv_cmd_map.rollrate, pv_value_map.bodyrate.rollrate,airspeed) + aileron_pid.output_neutral
    #   |> Common.Utils.Math.constrain(0, 1)
    # rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    # assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)

  end

end

#   use ExUnit.Case

#   setup do
#     vehicle_type = :Plane
#     Comms.ProcessRegistry.start_link()
#     Process.sleep(100)
#     pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
#     Pids.System.start_link(pid_config)

#     {:ok, [
#           pid_config: pid_config
#       ]}
#   end

#   test "LevelIITest", context do
#     IO.puts("LevelIITest")
#     max_rate_delta = 0.001
#     op_name = :batch_test
#     {:ok, _} = Comms.Operator.start_link(Configuration.Generic.get_operator_config(op_name))
#     dt = 0.05 # Not really used for now
#     pid_config = context[:pid_config]
#     # Setup parameters
#     pids = pid_config.pids
#     roll_pid = pids.roll
#     rollrate_pid = pids.rollrate
#     Process.sleep(200)
#     # ----- BEGIN AILERON TEST -----
#     # Update roll and yaw at the same time, which both affect aileron and rudder
#     # The aileron output will not be calculated until after the roll AND yaw
#     # PIDs have been updated.
#     pv_cmd_map = %{roll: 0.2, pitch: 3.0, yaw: -1.0, rollrate: 0.1}
#     pv_value_map = %{attitude: %{roll: 0.08, pitch: 1.0, yaw: -0.8}, bodyrate: %{rollrate: 0.01, pitchrate: -0.05, yawrate: 0.5}}
#     roll_corr= pv_cmd_map.roll - pv_value_map.attitude.roll
#     # Level II correction
#     Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 2}, pv_cmd_map, pv_value_map, dt}, {:pv_cmds_values, 2}, self())
#     Process.sleep(20)
#     exp_roll_rollrate_output = (roll_corr*roll_pid.rollrate.kp)*Map.get(roll_pid.rollrate, :weight,1)
#     # Rollrate
#     exp_rollrate_output =
#       exp_roll_rollrate_output + roll_pid.rollrate.output_neutral
#       |> Common.Utils.Math.constrain(roll_pid.rollrate.output_min, roll_pid.rollrate.output_max)
#     pv_cmd_map = Map.put(pv_cmd_map, :rollrate, Pids.Pid.get_output(:roll, :rollrate))
#     IO.puts("rollrate output: #{pv_cmd_map.rollrate}")
#     assert_in_delta(pv_cmd_map.rollrate, exp_rollrate_output, max_rate_delta)
#     # Level I correction
#     rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
#     exp_rollrate_aileron_output = (rollrate_corr*rollrate_pid.aileron.kp)*Map.get(rollrate_pid.aileron, :weight,1)
#     exp_aileron_output =
#       exp_rollrate_aileron_output + 0.5
#       |> Common.Utils.Math.constrain(0, 1)
#     aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
#     IO.puts("Aileron output: #{aileron_output}")
#     assert_in_delta(aileron_output, exp_aileron_output, max_rate_delta)
#   end

# end
