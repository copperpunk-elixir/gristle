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
    # Setup parameters
    pids = config.pid_config.pids
    roll_pid = pids.roll
    rollrate_pid = pids.rollrate
    Process.sleep(200)
    # ----- BEGIN AILERON TEST -----
    # Update roll and yaw at the same time, which both affect aileron and rudder
    # The aileron output will not be calculated until after the roll AND yaw
    # PIDs have been updated.
    pv_cmd_map = %{roll: 0.2, pitch: 3.0, yaw: -1.0, rollrate: 0.1}
    pv_value_map = %{attitude: %{roll: 0.08, pitch: 1.0, yaw: -0.8}, attitude_rate: %{rollrate: 0.01, pitchrate: -0.05, yawrate: 0.5}}
    roll_corr= pv_cmd_map.roll - pv_value_map.attitude.roll
    # Level II correction
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, :II}, pv_cmd_map, pv_value_map, dt}, {:pv_cmds_values, :II}, self())
    Process.sleep(20)
    exp_roll_rollrate_output = (roll_corr*roll_pid.rollrate.kp)*Map.get(roll_pid.rollrate, :weight,1)
    # Rollrate
    exp_rollrate_output =
      exp_roll_rollrate_output + roll_pid.rollrate.output_neutral
      |> Common.Utils.Math.constrain(roll_pid.rollrate.output_min, roll_pid.rollrate.output_max)
    pv_cmd_map = Map.put(pv_cmd_map, :rollrate, Pids.Pid.get_output(:roll, :rollrate))
    rollrate_corr = pv_cmd_map.rollrate - pv_value_map.attitude_rate.rollrate
    IO.puts("rollrate output: #{pv_cmd_map.rollrate}")
    assert_in_delta(pv_cmd_map.rollrate, exp_rollrate_output, max_rate_delta)
    # Level I correction
    rollrate_corr = pv_cmd_map.rollrate - pv_value_map.attitude_rate.rollrate
    exp_rollrate_aileron_output = (rollrate_corr*rollrate_pid.aileron.kp)*Map.get(rollrate_pid.aileron, :weight,1)
    exp_aileron_output =
      exp_rollrate_aileron_output + 0.5
      |> Common.Utils.Math.constrain(0, 1)
    aileron_output = Pids.Pid.get_output(:rollrate, :aileron)
    IO.puts("Aileron output: #{aileron_output}")
    assert_in_delta(aileron_output, exp_aileron_output, max_rate_delta)
  end

end
