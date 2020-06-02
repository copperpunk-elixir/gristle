defmodule Pids.LevelITest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    pid_config = Configuration.Vehicle.Plane.Pids.get_config()

    {:ok, [
        config: pid_config
      ]}
  end

  test "start PID server", context do
    config = %{}
    config = Map.merge(context[:config], config)
    {:ok, process_id} = Pids.System.start_link(config)
    assert process_id == GenServer.whereis(Pids.System)
  end

  test "update PID and check output", context do
    max_delta = 0.001
    op_name = :start_pid_test
    Comms.Operator.start_link(%{name: op_name})
    config =context[:config]
    Pids.System.start_link(config)
    Process.sleep(300)
    pv_cmd_map = %{rollrate: 0.0556}
    pv_value_map = %{bodyrate: %{rollrate: 0}}
    rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    exp_rollrate_aileron_output =
      get_in(config, [:pids, :rollrate, :aileron, :kp])*rollrate_corr + 0.5
      |> Common.Utils.Math.constrain(0, 1)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)
    # Check out of bounds, to the right
    pv_value_map = %{bodyrate: %{rollrate: 2.0}}
    # rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    exp_rollrate_aileron_output = 0.0
    Process.sleep(20)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)
    # Check out of bounds, to the left
    pv_value_map = %{bodyrate: %{rollrate: -2.0}}
    # rollrate_corr = pv_cmd_map.rollrate - pv_value_map.bodyrate.rollrate
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    exp_rollrate_aileron_output = 1.0
    Process.sleep(20)
    rollrate_aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    assert_in_delta(rollrate_aileron_output, exp_rollrate_aileron_output, max_delta)
  end
end
