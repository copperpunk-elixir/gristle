defmodule Pid.PidTest do
  require Logger
  use ExUnit.Case
  doctest Pid.Pid

  compare_delta = 1.0e-6

  # Common.Utils.Comms.start_registry(:topic_registry)
  Common.ProcessRegistry.start_link


  pid_config = %{
    process_variable: :roll,
    actuator: :aileron,
    kp: 20.0,
    ki: 0,
    kd: 0.005,
    rate_or_position: :rate,
    one_or_two_sided: :two_sided
  }
  # Test 1 - Single PID updates
  Pid.Pid.start_link(pid_config)
  current_cmd = Pid.Pid.get_initial_output(pid_config.one_or_two_sided)
  assert_in_delta(Pid.Pid.get_cmd_for_error(:roll, :aileron, 0, 0, 1), current_cmd, compare_delta)
  cmd_error = 0.01
  rate_act = 1.0
  dt = 1.0
  # Update PID
  Pid.Pid.get_cmd_for_error(:roll, :aileron, cmd_error, rate_act, dt)
  expected_cmd = Common.Utils.Math.constrain(((cmd_error*pid_config.kp) - rate_act)*pid_config.kd + 0.5, 0,1)
  assert_in_delta(Pid.Pid.get_last_cmd(:roll, :aileron), expected_cmd, compare_delta)

  # Test 2 - Several PID updates in a row
  pid_config_2 = %{pid_config | process_variable: :pitch, actuator: :elevator,  rate_or_position: :position}
  Pid.Pid.start_link(pid_config_2)
  num_steps = 20
  Enum.each(1..num_steps, fn _ ->
    Pid.Pid.get_cmd_for_error(:pitch, :elevator, cmd_error, rate_act, dt)
  end)
  initial_output = Pid.Pid.get_initial_output(pid_config_2.one_or_two_sided)
  expected_cmd = Common.Utils.Math.constrain(num_steps * ((cmd_error*pid_config.kp) - rate_act)*pid_config.kd + initial_output, 0,1)
  assert_in_delta(Pid.Pid.get_last_cmd(:pitch, :elevator), expected_cmd, 0.00001)

  # Test 3 - Add support for integrators
  # Fail this for now, because it hasn't been tested
  assert true == false
end
