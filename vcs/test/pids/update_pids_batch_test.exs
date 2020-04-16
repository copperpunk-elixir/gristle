defmodule Pids.UpdatePidsBatchTest do
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

  test "Updates PIDs with batch operation, send to Actuators", context do
    IO.puts("UpdatePidsBatchTest")
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
    roll_rudder_weight = roll_pid.rudder.weight
    yaw_pid = pids.yaw
    yaw_aileron_weight = yaw_pid.aileron.weight
    yaw_rudder_weight = yaw_pid.rudder.weight
    total_aileron_weight = roll_aileron_weight + yaw_aileron_weight
    total_rudder_weight = roll_rudder_weight + yaw_rudder_weight
    vx_pid = pids.vx
    vx_throttle_weight = vx_pid.throttle.weight
    total_throttle_weight = vx_throttle_weight
    # rate_or_position_all = config.pid_config.rate_or_position
    one_or_two_sided_all = config.pid_config.one_or_two_sided

    # ----- BEGIN AILERON AND RUDDER TEST -----
    # Update roll and yaw at the same time, which both affect aileron and rudder
    # The aileron output will not be calculated until after the roll AND yaw
    # PIDs have been updated.
    roll_error = 0.12
    yaw_error = -0.2
    pv_error = %{roll: roll_error, yaw: yaw_error}
    Pids.System.update_pids_for_pvs_and_errors(pv_error, dt)
    Process.sleep(60)
    exp_roll_aileron_output =
      roll_error*roll_pid.aileron.kp*roll_aileron_weight/total_aileron_weight
    exp_yaw_aileron_output = yaw_error*yaw_pid.aileron.kp*yaw_aileron_weight/total_aileron_weight
    exp_roll_rudder_output = roll_error*roll_pid.rudder.kp*roll_rudder_weight/total_rudder_weight
    exp_yaw_rudder_output = yaw_error*yaw_pid.rudder.kp*yaw_rudder_weight/total_rudder_weight
    # Aileron
    exp_aileron_total_output =
      exp_roll_aileron_output + exp_yaw_aileron_output + Pids.Pid.get_initial_output(one_or_two_sided_all.aileron)
      |> Pids.System.constrain_output()
    exp_aileron_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      aileron_actuator, exp_aileron_total_output)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(aileron_actuator), exp_aileron_pw, 0.25)
    # Rudder
    exp_rudder_total_output =
      exp_roll_rudder_output + exp_yaw_rudder_output + Pids.Pid.get_initial_output(one_or_two_sided_all.rudder)
      |> Pids.System.constrain_output()
    exp_rudder_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      rudder_actuator, exp_rudder_total_output)
    assert_in_delta(Actuation.HwInterface.get_output_for_actuator(rudder_actuator), exp_rudder_pw, 0.25)
    # ----- END AILERON TEST -----
    # ----- BEGIN THROTTLE TEST -----
    vx_error = 0.1
    pv_error = %{vx: vx_error}
    Pids.System.update_pids_for_pvs_and_errors(pv_error, dt)
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
  end

end
