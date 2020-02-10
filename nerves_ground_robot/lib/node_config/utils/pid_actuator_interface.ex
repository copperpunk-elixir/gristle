defmodule NodeConfig.Utils.PidActuatorInterface do
  require Logger

  # Pid-to-Actuator config
  def new_pid_to_actuator_config() do
    %{}
  end

  def add_pid_actuator(pid_to_actuators, process_variable, actuator_name) do
    key =
      Atom.to_string(process_variable) <> "_to_" <> Atom.to_string(actuator_name)
      |> String.to_atom()
    value = %{process_variable: process_variable, actuator: actuator_name, output: 0}
    Map.put(pid_to_actuators, key, value)
  end

  # PID config
  def new_pid_config do
    %{}
  end

  def add_pid(pids, process_variable, actuator, kp, ki, kd, rate_or_position, one_or_two_sided) do
    pid = %{
      kp: kp,
      ki: ki,
      kd: kd,
      rate_or_position: rate_or_position,
      one_or_two_sided: one_or_two_sided,
      offset: 0
    }
    process_variable_actuators =
      Map.get(pids, process_variable, %{})
      |> Map.put(actuator, pid)
    Map.put(pids, process_variable, process_variable_actuators)
  end

  # Actuators config
  def new_actuators_config() do
    %{}
  end

  def add_actuator(actuators, actuator_name, channel_number, reversed, min_pw_ms, max_pw_ms) do
    actuator = %{channel_number: channel_number, reversed: reversed, min_pw_ms: min_pw_ms, max_pw_ms: max_pw_ms}
    Map.put(actuators, actuator_name, actuator)
  end
end
