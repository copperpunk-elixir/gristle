defmodule NodeConfig.Utils.PidActuatorInterface do
  require Logger

  # Pid-to-Actuator config
  def new_pid_actuator_config() do
    []
  end

  def add_pid_actuator_link(pid_actuator_links, new_link) do
    pid_actuator_link = %{
      process_variable: new_link.process_variable,
      actuator: new_link.actuator,
      cmd_limit_min: new_link.cmd_limit_min,
      cmd_limit_max: new_link.cmd_limit_max,
      failsafe_cmd: new_link.failsafe_cmd
    }
    [pid_actuator_link | pid_actuator_links]
  end

  # PID config
  def new_pid_config do
    %{}
  end

  def add_pid(pids, new_pid) do
    pid = %{
      kp: new_pid.kp,
      ki: new_pid.ki,
      kd: new_pid.kd,
      rate_or_position: new_pid.rate_or_position,
      one_or_two_sided: new_pid.one_or_two_sided,
      offset: Map.get(new_pid, :offset, 0)
    }
    process_variable_actuators =
      Map.get(pids, new_pid.process_variable, %{})
      |> Map.put(new_pid.actuator, pid)
    Map.put(pids, new_pid.process_variable, process_variable_actuators)
  end

  # Actuators config
  def new_actuators_config() do
    %{}
  end

  def add_actuator(actuators, new_actuator) do
    actuator = %{
      channel_number: new_actuator.channel_number,
      reversed: new_actuator.reversed,
      min_pw_ms: new_actuator.min_pw_ms,
      max_pw_ms: new_actuator.max_pw_ms,
      cmd_limit_min: new_actuator.cmd_limit_min,
      cmd_limit_max: new_actuator.cmd_limit_max,
      failsafe_cmd: new_actuator.failsafe_cmd
    }
    Map.put(actuators, new_actuator.name, actuator)
  end
end
