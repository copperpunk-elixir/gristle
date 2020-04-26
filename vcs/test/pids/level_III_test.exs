defmodule Pids.LevelIIITest do
  use ExUnit.Case

  setup do
    pid_config = TestConfigs.Pids.get_pid_config_plane()
    {:ok, _} = Comms.ProcessRegistry.start_link()
    {:ok, _} = Pids.System.start_link(pid_config)
    MessageSorter.System.start_link()
    Process.sleep(200)
    MessageSorter.System.start_sorter(%{name: {:pv_cmds, :roll}, default_message_behavior: :default_value, default_value: 0})
    MessageSorter.System.start_sorter(%{name: {:pv_cmds, :yaw}, default_message_behavior: :default_value, default_value: 0})

    {:ok, [
        config: %{
          pid_config: pid_config,
        }
      ]}
  end

  test "LevelIITest", context do
    IO.puts("LevelIIITest")
    max_rate_delta = 0.001
    op_name = :batch_test
    {:ok, _} = Comms.Operator.start_link(%{name: op_name})
    dt = 0.05
    config = %{}
    config = Map.merge(context[:config], config)
    Process.sleep(200)
    # Setup parameters
    pids = config.pid_config.pids
    heading_pid = pids.heading
    roll_pid = pids.roll
    yaw_pid = pids.yaw
    rollrate_pid = pids.rollrate
    yawrate_pid = pids.yawrate
    one_or_two_sided_all = config.pid_config.one_or_two_sided

    # ----- BEGIN HEADING-to-ROLL/YAW RUDDER TEST -----
    # Update heading, which affects both roll and yaw 
    pv_cmd_map = %{heading: 0.3}
    pv_value_map = %{heading: -0.2}
    heading_corr= pv_cmd_map.heading - pv_value_map.heading
    # Level III correction
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, :III}, pv_cmd_map, pv_value_map, dt}, {:pv_cmds_values, :III}, self())
    Process.sleep(50)
    exp_heading_roll_output = heading_corr*heading_pid.roll.kp
    exp_heading_yaw_output = heading_corr*heading_pid.yaw.kp
    exp_roll_output =
    (exp_heading_roll_output + Pids.Pid.get_initial_output(one_or_two_sided_all.roll, heading_pid.roll.output_min, heading_pid.roll.output_neutral))*Map.get(heading_pid.roll, :weight, 1)
      |> Common.Utils.Math.constrain(heading_pid.roll.output_min, heading_pid.roll.output_max)
    exp_yaw_output = (exp_heading_yaw_output + Pids.Pid.get_initial_output(one_or_two_sided_all.yaw, heading_pid.yaw.output_min, heading_pid.yaw.output_neutral))*Map.get(heading_pid.yaw, :weight, 1)
    |> Common.Utils.Math.constrain(heading_pid.yaw.output_min, heading_pid.yaw.output_max)
    Process.sleep(50)
    roll_output = Pids.Pid.get_output(:heading, :roll, Map.get(heading_pid.roll,:weight,1))
    yaw_output = Pids.Pid.get_output(:heading, :yaw, Map.get(heading_pid.yaw,:weight,1))
    roll_cmd = MessageSorter.Sorter.get_value({:pv_cmds, :roll})
    yaw_cmd = MessageSorter.Sorter.get_value({:pv_cmds, :yaw})

    assert_in_delta(roll_output, exp_roll_output, max_rate_delta)
    assert_in_delta(roll_cmd, exp_roll_output, max_rate_delta)
    assert_in_delta(yaw_output, exp_yaw_output, max_rate_delta)
    assert_in_delta(yaw_cmd, exp_yaw_output, max_rate_delta)
  end

end

