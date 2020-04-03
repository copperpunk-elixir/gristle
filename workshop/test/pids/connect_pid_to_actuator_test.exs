defmodule Pids.ConnectPidToActuatorTest do
  use ExUnit.Case

  setup do
    hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    actuator_list = [:aileron, :rudder, :throttle]
    channels_list = [0,1,2]
    failsafes_list = [0.5, 0.5, 0.0]
    actuator_config = TestConfigs.Actuation.get_sw_config_actuators(actuator_list, channels_list, failsafes_list)
    pid_config = TestConfigs.Pids.get_pid_config_roll_yaw()

    {:ok, registry_pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(registry_pid)

    {:ok, process_id} = Pids.System.start_link(pid_config)
    Common.Utils.wait_for_genserver_start(process_id)

    {:ok, process_id} = Actuation.HwInterface.start_link(hw_interface_config)
    Common.Utils.wait_for_genserver_start(process_id)

    {:ok, process_id} = Actuation.SwInterface.start_link(actuator_config)
    Common.Utils.wait_for_genserver_start(process_id)

    {:ok, [
        config: %{
          pid_config: pid_config,
          hw_interface_config: hw_interface_config,
          actuator_config: actuator_config,
        }
      ]}
  end

  test "Send PID output to Actuation SwInterface, check HwInterface output", context do
    dt = 0.05 # Not really used for now
    config = %{}
    config = Map.merge(context[:config], config)
    aileron_actuator = config.actuator_config.actuators.aileron
    rudder_actuator = config.actuator_config.actuators.rudder
    throttle_actuator = config.actuator_config.actuators.throttle
    Process.sleep(100)
    # There has been no pid update, so the actuator should be at its failsafe value
    failsafe_output = aileron_actuator.min_pw_ms + (aileron_actuator.max_pw_ms - aileron_actuator.min_pw_ms)*aileron_actuator.failsafe_cmd
    assert Actuation.HwInterface.get_output_for_actuator(aileron_actuator) == failsafe_output
    # Setup parameters
    pids = config.pid_config.pids
    roll_pid = pids.roll
    roll_aileron_weight = roll_pid.aileron.weight
    yaw_pid = pids.yaw
    yaw_aileron_weight = yaw_pid.aileron.weight
    total_aileron_weight = roll_aileron_weight + yaw_aileron_weight
    vx_pid = pids.vx
    vx_throttle_weight = vx_pid.throttle.weight
    total_throttle_weight = vx_throttle_weight
    # rate_or_position_all = config.pid_config.rate_or_position
    one_or_two_sided_all = config.pid_config.one_or_two_sided

    # ----- BEGIN AILERON TEST -----
    # A non-zero pv_error was sent to the pid, therefore the actuator output should
    # not be the neutral value
    roll_error = 0.2
    Pids.System.update_pids(:roll, roll_error, dt)
    Process.sleep(60)
    exp_roll_aileron_output =
      roll_error*roll_pid.aileron.kp*roll_aileron_weight/total_aileron_weight
    exp_total_output =
      exp_roll_aileron_output + Pids.Pid.get_initial_output(one_or_two_sided_all.aileron)
      |> Pids.System.constrain_output()
    exp_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      aileron_actuator, exp_total_output)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(aileron_actuator), exp_pw, 0.25)
    # Add yaw to the mix
    yaw_error = 0.2
    Pids.System.update_pids(:yaw, yaw_error, dt)
    exp_yaw_aileron_output = yaw_error*yaw_pid.aileron.kp*yaw_aileron_weight/total_aileron_weight
    exp_total_output =
      exp_roll_aileron_output + exp_yaw_aileron_output + Pids.Pid.get_initial_output(one_or_two_sided_all.aileron)
    |> Pids.System.constrain_output()
    exp_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      aileron_actuator, exp_total_output)
    Process.sleep(60)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(aileron_actuator), exp_pw, 0.25)
    # Throttle has not received a command, so it should be at its failsafe value
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(throttle_actuator), throttle_actuator.min_pw_ms, 0.25)
    # ----- END AILERON TEST -----
    # ----- BEGIN THROTTLE TEST -----
    vx_error = 0.1
    Pids.System.update_pids(:vx, vx_error, dt)
    Process.sleep(60)
    exp_vx_throttle_output =
      vx_error*vx_pid.throttle.kp*vx_throttle_weight/total_throttle_weight
    exp_total_output =
      exp_vx_throttle_output + Pids.Pid.get_initial_output(one_or_two_sided_all.throttle)
      |> Pids.System.constrain_output()
    exp_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      throttle_actuator, exp_total_output)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(throttle_actuator), exp_pw, 0.25)
    # Throttle is :position style PID, so if we apply another vx_error, the output should add
    Pids.System.update_pids(:vx, vx_error, dt)
    Pids.System.update_pids(:vx, vx_error, dt)
    Pids.System.update_pids(:vx, vx_error, dt)
    Process.sleep(60)
    exp_vx_throttle_output =
      4*vx_error*vx_pid.throttle.kp*vx_throttle_weight/total_throttle_weight
    exp_total_output =
      exp_vx_throttle_output + Pids.Pid.get_initial_output(one_or_two_sided_all.throttle)
      |> Pids.System.constrain_output()
    exp_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      throttle_actuator, exp_total_output)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(throttle_actuator), exp_pw, 0.25)
    # Allow valid Actuator cmds to expire
    Process.sleep(160)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(aileron_actuator), Actuation.HwInterface.get_failsafe_pw_for_actuator(aileron_actuator), 0.25)
    Process.sleep(200)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(throttle_actuator), Actuation.HwInterface.get_failsafe_pw_for_actuator(throttle_actuator), 0.25)
  end

end
