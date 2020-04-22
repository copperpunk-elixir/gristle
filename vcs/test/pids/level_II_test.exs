defmodule Pids.LevelIITest do
  use ExUnit.Case

  setup do
    hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    actuator_list = [:aileron, :rudder, :throttle]
    channels_list = [0,1,2]
    failsafes_list = [0.5, 0.5, 0.0]
    actuator_config = TestConfigs.Actuation.get_sw_config_actuators(actuator_list, channels_list, failsafes_list)
    pid_config = TestConfigs.Pids.get_pid_config_plane()

    {:ok, _} = Comms.ProcessRegistry.start_link()
    {:ok, _} = Pids.System.start_link(pid_config)
    {:ok, _} = Actuation.HwInterface.start_link(hw_interface_config)
    {:ok, _} = Actuation.SwInterface.start_link(actuator_config)

    {:ok, [
        config: %{
          pid_config: pid_config,
          hw_interface_config: hw_interface_config,
          actuator_config: actuator_config,
        }
      ]}
  end

  test "LevelIITest", context do
    IO.puts("LevelIITest")
    max_rate_delta = 0.001
    op_name = :batch_test
    {:ok, _} = Comms.Operator.start_link(%{name: op_name})
    dt = 0.05 # Not really used for now
    config = %{}
    config = Map.merge(context[:config], config)
    aileron_actuator = config.actuator_config.actuators.aileron
    Process.sleep(200)
    # There has been no pid update, so the actuator should be at its failsafe value
    failsafe_output = aileron_actuator.min_pw_ms + (aileron_actuator.max_pw_ms - aileron_actuator.min_pw_ms)*aileron_actuator.failsafe_cmd
    assert Actuation.HwInterface.get_output_for_actuator(aileron_actuator) == failsafe_output
    # Setup parameters
    pids = config.pid_config.pids
    roll_pid = pids.roll
    rollrate_pid = pids.rollrate
    one_or_two_sided_all = config.pid_config.one_or_two_sided

    # ----- BEGIN AILERON TEST -----
    # Update roll and yaw at the same time, which both affect aileron and rudder
    # The aileron output will not be calculated until after the roll AND yaw
    # PIDs have been updated.
    roll_correction = 0.12
    pitch_correction = 2.0
    yaw_correction = -0.2
    pv_correction = %{roll: roll_correction,pitch: pitch_correction, yaw: yaw_correction}
    pv_feed_forward = %{}
    # Level II correction
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_correction, :II}, pv_correction, pv_feed_forward, dt}, {:pv_correction, :II}, self())
    Process.sleep(20)
    exp_roll_rollrate_output = (roll_correction*roll_pid.rollrate.kp)*roll_pid.rollrate.weight
    # Rollrate
    exp_rollrate_output =
      exp_roll_rollrate_output + Pids.Pid.get_initial_output(one_or_two_sided_all.rollrate, roll_pid.rollrate.output_min, roll_pid.rollrate.output_neutral)
      |> Common.Utils.Math.constrain(roll_pid.rollrate.output_min, roll_pid.rollrate.output_max)
    rollrate_output = Pids.Pid.get_output(:roll, :rollrate)
    IO.puts("rollrate output: #{rollrate_output}")
    assert_in_delta(rollrate_output, exp_rollrate_output, max_rate_delta)
    # Level I correction
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_correction, :I}, %{rollrate: rollrate_output}, %{}, dt}, {:pv_correction, :I}, self())
    Process.sleep(20)
    exp_rollrate_aileron_output = (rollrate_output*rollrate_pid.aileron.kp)*rollrate_pid.aileron.weight
    exp_aileron_output =
      exp_rollrate_aileron_output + Pids.Pid.get_initial_output(one_or_two_sided_all.aileron, 0, 0.5)
      |> Common.Utils.Math.constrain(0, 1)
    aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    assert_in_delta(aileron_output, exp_aileron_output, max_rate_delta)
  end

end
