defmodule Pids.LevelIIITest do
  use ExUnit.Case

  setup do
    hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    actuator_list = [:aileron, :rudder, :throttle]
    channels_list = [0,1,2]
    failsafes_list = [0.5, 0.5, 0.0]
    actuator_config = TestConfigs.Actuation.get_sw_config_actuators(actuator_list, channels_list, failsafes_list)
    pid_config = TestConfigs.Pids.get_pid_config_a()

    {:ok, _} = Comms.ProcessRegistry.start_link()
    {:ok, _} = Pids.System.start_link(pid_config)
    {:ok, _} = Actuation.HwInterface.start_link(hw_interface_config)
    {:ok, _} = Actuation.SwInterface.start_link(actuator_config)
    Process.sleep(200)
    MessageSorter.System.start_sorter(%{name: {:pv_cmds, :roll}, default_message_behavior: :default_value, default_value: 0})
    MessageSorter.System.start_sorter(%{name: {:pv_cmds, :yaw}, default_message_behavior: :default_value, default_value: 0})

    {:ok, [
        config: %{
          pid_config: pid_config,
          hw_interface_config: hw_interface_config,
          actuator_config: actuator_config,
        }
      ]}
  end

  test "LevelIITest", context do
    IO.puts("LevelIIITest")
    max_rate_delta = 0.001
    max_pw_delta = 0.25
    op_name = :batch_test
    {:ok, _} = Comms.Operator.start_link(%{name: op_name})
    dt = 0.05 # Not really used for now
    config = %{}
    config = Map.merge(context[:config], config)
    aileron_actuator = config.actuator_config.actuators.aileron
    rudder_actuator = config.actuator_config.actuators.rudder
    Process.sleep(200)
    # There has been no pid update, so the actuator should be at its failsafe value
    # Setup parameters
    pids = config.pid_config.pids
    heading_pid = pids.heading
    roll_pid = pids.roll
    # pitch_pid = pids.pitch
    yaw_pid = pids.yaw
    rollrate_pid = pids.rollrate
    yawrate_pid = pids.yawrate
    # rate_or_position_all = config.pid_config.rate_or_position
    one_or_two_sided_all = config.pid_config.one_or_two_sided

    # ----- BEGIN AILERON AND RUDDER TEST -----
    # Update roll and yaw at the same time, which both affect aileron and rudder
    # The aileron output will not be calculated until after the roll AND yaw
    # PIDs have been updated.
    heading_correction = -0.2
    pv_correction = %{heading: heading_correction}#, altitude: 10}
    pv_feed_forward = %{heading: %{roll: 0, yaw: 0}}
    # Level II correction
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_correction, :III}, pv_correction, pv_feed_forward, dt}, {:pv_correction, :III}, self())
    Process.sleep(50)
    exp_heading_roll_output = (heading_correction*heading_pid.roll.kp + pv_feed_forward.heading.roll)*heading_pid.roll.weight
    exp_heading_yaw_output = (heading_correction*heading_pid.yaw.kp + pv_feed_forward.heading.yaw)*heading_pid.yaw.weight
    exp_roll_output =
      exp_heading_roll_output + Pids.Pid.get_initial_output(one_or_two_sided_all.roll, heading_pid.roll.output_min, heading_pid.roll.output_neutral)
      |> Common.Utils.Math.constrain(heading_pid.roll.output_min, heading_pid.roll.output_max)
    exp_yaw_output = exp_heading_yaw_output + Pids.Pid.get_initial_output(one_or_two_sided_all.yaw, heading_pid.yaw.output_min, heading_pid.yaw.output_neutral)
    |> Common.Utils.Math.constrain(heading_pid.yaw.output_min, heading_pid.yaw.output_max)
    Process.sleep(50)
    roll_output = Pids.Pid.get_output(:heading, :roll, heading_pid.roll.weight)
    yaw_output = Pids.Pid.get_output(:heading, :yaw, heading_pid.yaw.weight)
    roll_cmd = MessageSorter.Sorter.get_value({:pv_cmds, :roll})
    yaw_cmd = MessageSorter.Sorter.get_value({:pv_cmds, :yaw})

    assert_in_delta(roll_output, exp_heading_roll_output, max_rate_delta)
    assert_in_delta(roll_cmd, exp_heading_roll_output, max_rate_delta)
    assert_in_delta(yaw_output, exp_heading_yaw_output, max_rate_delta)
    assert_in_delta(yaw_cmd, exp_heading_yaw_output, max_rate_delta)
  end

end

