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
    heading_correction = -0.2
    pv_correction = %{heading: heading_correction}#, altitude: 10}
    pv_feed_forward = %{heading: %{roll: 0, yaw: 0}}
    # Level III correction
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_correction, :III}, pv_correction, pv_feed_forward, dt}, {:pv_correction, :III}, self())
    Process.sleep(50)
    exp_heading_roll_output = heading_correction*heading_pid.roll.kp + pv_feed_forward.heading.roll
    exp_heading_yaw_output = heading_correction*heading_pid.yaw.kp + pv_feed_forward.heading.yaw
    exp_roll_output =
    (exp_heading_roll_output + Pids.Pid.get_initial_output(one_or_two_sided_all.roll, heading_pid.roll.output_min, heading_pid.roll.output_neutral))*heading_pid.roll.weight
      |> Common.Utils.Math.constrain(heading_pid.roll.output_min, heading_pid.roll.output_max)
    exp_yaw_output = (exp_heading_yaw_output + Pids.Pid.get_initial_output(one_or_two_sided_all.yaw, heading_pid.yaw.output_min, heading_pid.yaw.output_neutral))*heading_pid.yaw.weight
    |> Common.Utils.Math.constrain(heading_pid.yaw.output_min, heading_pid.yaw.output_max)
    Process.sleep(50)
    roll_output = Pids.Pid.get_output(:heading, :roll, heading_pid.roll.weight)
    yaw_output = Pids.Pid.get_output(:heading, :yaw, heading_pid.yaw.weight)
    roll_cmd = MessageSorter.Sorter.get_value({:pv_cmds, :roll})
    yaw_cmd = MessageSorter.Sorter.get_value({:pv_cmds, :yaw})

    assert_in_delta(roll_output, exp_roll_output, max_rate_delta)
    assert_in_delta(roll_cmd, exp_roll_output, max_rate_delta)
    assert_in_delta(yaw_output, exp_yaw_output, max_rate_delta)
    assert_in_delta(yaw_cmd, exp_yaw_output, max_rate_delta)
  end

end

