defmodule Pids.LevelITest do
  use ExUnit.Case
  require Logger
  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  # test "start PID server", context do
  #   assert process_id == GenServer.whereis(Pids.System)
  # end

  # test "update P-controller and check output" do
  #   vehicle_type = :Plane
  #   pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
  #   Pids.System.start_link(pid_config)

  #   max_delta = 0.001
  #   op_name = :start_pid_test
  #   Comms.Operator.start_link(Configuration.Generic.get_operator_config(op_name))
  #   Process.sleep(300)
  #   pv_cmd_map = %{rollrate: 0.0556}
  #   pv_value_map = %{bodyrate: %{rollrate: 0}}
  #   rollrate_corr = Common.Utils.Math.constrain(pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate, pid_config.pids.rollrate.aileron.input_min, pid_config.pids.rollrate.aileron.input_max)
  #   Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
  #   Process.sleep(100)
  #   rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
  #   exp_rollrate_aileron_output =
  #     get_in(pid_config, [:pids, :rollrate, :aileron, :kp])*rollrate_corr + 0.5
  #     |> Common.Utils.Math.constrain(0, 1)
  #   assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)
  # end


  test "update PID-controller and check output" do
    vehicle_type = :Plane
    pid_config = %{
      pids: %{rollrate: %{
                 aileron: %{
                   kp: 1.0,
                   ki: 0.1,
                   kd: 0.1,
                   output_min: 0,
                   output_neutral: 0.5,
                   output_max: 1.0,
                   input_min: -1.57,
                   input_max: 1.57
                 }}
             },
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
    Pids.System.start_link(pid_config)

    max_delta = 0.00001
    op_name = :start_pid_test
    aileron_pid = pid_config.pids.rollrate.aileron
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(op_name))
    Process.sleep(300)
    pv_cmd_map = %{rollrate: 0.4}
    pv_value_map = %{bodyrate: %{rollrate: 0}}
    dt = 0.05
    rollrate_corr = Common.Utils.Math.constrain(pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate, aileron_pid.input_min, aileron_pid.input_max)
    rollrate_corr_prev = 0
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    exp_rollrate_aileron_output =
      aileron_pid.kp*rollrate_corr + aileron_pid.ki*rollrate_corr*dt - aileron_pid.kd*(rollrate_corr - rollrate_corr_prev) + aileron_pid.output_neutral
      |> Common.Utils.Math.constrain(0, 1)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)
    rollrate_corr_prev = rollrate_corr
    # Another cycle
    pv_value_map = %{bodyrate: %{rollrate: 0}}
    rollrate_corr = Common.Utils.Math.constrain(pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate, aileron_pid.input_min, aileron_pid.input_max)
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    exp_rollrate_aileron_output =
      aileron_pid.kp*rollrate_corr + aileron_pid.ki*(rollrate_corr + rollrate_corr_prev)*dt - aileron_pid.kd*(rollrate_corr - rollrate_corr_prev) + aileron_pid.output_neutral
      |> Common.Utils.Math.constrain(0, 1)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)

  end

end
