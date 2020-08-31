defmodule Pids.LevelITest do
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
    pv_cmd_map = %{rollrate: 0.2, pitchrate: 0, yawrate: 0, thrust: 0.0}
    pv_value_map = %{bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    airspeed = 10
    dt = 0.05
    rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
    rollrate_corr_prev = 0
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    Logger.debug("ail: #{rollrate_aileron_output}")
    Process.sleep(200)
    exp_rollrate_aileron_output =
      aileron_pid.kp*rollrate_corr + aileron_pid.ki*rollrate_corr*dt + aileron_pid.ff.(pv_cmd_map.rollrate, pv_value_map.bodyrate.rollrate,airspeed) + aileron_pid.output_neutral
      |> Common.Utils.Math.constrain(0, 1)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)
    rollrate_corr_prev = rollrate_corr
    # Another cycle
    rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    exp_rollrate_aileron_output =
      aileron_pid.kp*rollrate_corr + aileron_pid.ki*(rollrate_corr+rollrate_corr_prev)*dt + aileron_pid.ff.(pv_cmd_map.rollrate, pv_value_map.bodyrate.rollrate,airspeed) + aileron_pid.output_neutral
      |> Common.Utils.Math.constrain(0, 1)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)

  end

end
