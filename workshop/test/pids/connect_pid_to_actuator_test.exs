defmodule Controller.Pid.ConnectPidToActuatorTest do
  use ExUnit.Case

  setup do
    actuator_name = :aileron
    hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    sw_interface_config = TestConfigs.Actuation.get_sw_config_single_actuator(actuator_name)
    pid_config = TestConfigs.Pids.get_pid_config_roll_yaw()

    {:ok, registry_pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(registry_pid)

    {:ok, process_id} = Pids.System.start_link(pid_config)
    Common.Utils.wait_for_genserver_start(process_id)

    {:ok, process_id} = Actuation.HwInterface.start_link(hw_interface_config)
    Common.Utils.wait_for_genserver_start(process_id)

    {:ok, process_id} = Actuation.SwInterface.start_link(sw_interface_config)
    Common.Utils.wait_for_genserver_start(process_id)

    {:ok, [
        config: %{
          pid_config: pid_config,
          hw_interface_config: hw_interface_config,
          sw_interface_config: sw_interface_config,
          actuator_name: actuator_name
        }
      ]}
  end

  test "Send PID output to Actuation SwInterface, check HwInterface output", context do
    config = %{}
    config = Map.merge(context[:config], config)
    actuator = config.sw_interface_config.actuators[config.actuator_name]
    Process.sleep(100)
    # There has been no pid update, so the actuator should be at its failsafe value
    failsafe_output = actuator.min_pw_ms + (actuator.max_pw_ms - actuator.min_pw_ms)*actuator.failsafe_cmd
    assert Actuation.HwInterface.get_actuator_output(actuator) == failsafe_output
    # Setup parameters
    roll_pid = config.pid_config.pids.roll
    roll_weight = get_in(roll_pid, [config.actuator_name, :weight])
    yaw_pid = config.pid_config.pids.yaw
    yaw_weight = get_in(yaw_pid, [config.actuator_name, :weight])
    total_weight = roll_weight + yaw_weight
    neutral_output = 0.5
    # A non-zero pv_error was sent to the pid, therefore the actuator output should
    # not be the neutral value
    roll_error = 1
    Pids.System.update_pids(:roll, roll_error, 0.05)
    Process.sleep(60)
    expected_roll_aileron_output = roll_error*get_in(roll_pid, [config.actuator_name, :kp])*roll_weight/total_weight
    expected_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      actuator, Pids.System.constrain_output(expected_roll_aileron_output + neutral_output))
    assert_in_delta(Actuation.HwInterface.get_actuator_output(actuator), expected_pw, 0.25)
    # Add yaw to the mix
    yaw_error = 0.2
    Pids.System.update_pids(:yaw, yaw_error, 0.05)
    expected_yaw_aileron_output = yaw_error*get_in(yaw_pid, [config.actuator_name, :kp])*yaw_weight/total_weight
    expected_total_output = Pids.System.constrain_output(expected_roll_aileron_output + expected_yaw_aileron_output + neutral_output)
    expected_pw = Actuation.HwInterface.get_pw_for_actuator_and_output(Peripherals.Uart.PololuServo,
      actuator, expected_total_output)
    Process.sleep(60)
    assert_in_delta(Actuation.HwInterface.get_actuator_output(actuator), expected_pw, 0.25)
  end

end
