defmodule Pid.Controller do
  use Supervisor
  require Logger

  def start_link(pid_controller_config) do
    Logger.debug("Start PidController")
    # config = Common.Config.get_config_map()
    # pid_controller_config = config.pid_controller
    Supervisor.start_link(
      __MODULE__,
      pid_controller_config,
      name: __MODULE__
    )
  end

  @impl true
  def init(config) do
    children = Enum.reduce(config.pids,[], fn ({process_variable, actuators}, acc) ->
      child_spec_list =
        Enum.map(actuators, fn {actuator, pid} ->
          Logger.debug("create pid (#{process_variable}/#{actuator}): #{inspect(pid)}")
          pid_config =
            %{
              name: {process_variable, actuator},
              kp: pid.kp,
              ki: pid.ki,
              kd: pid.kd,
              rate_or_position: pid.rate_or_position,
              one_or_two_sided: pid.one_or_two_sided,
              offset: pid.offset
            }
          Supervisor.child_spec({Pid.Pid, pid_config}, id: pid_config.name)
        end)
      acc ++ child_spec_list
    end)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def update_pid(process_variable, actuator, cmd_error, euler_rate, dt, caller) do
    output = Pid.Pid.get_cmd_for_error(process_variable, actuator, cmd_error, euler_rate, dt)
    # Return the output to the original caller (Gimbal.System)
    GenServer.cast(caller, {:pid_updated, process_variable, actuator, output})
  end

  def set_pid_gain(process_variable, actuator, gain_name, gain_value) do
    Logger.debug("update pid for #{process_variable}/#{actuator}")
    Pid.Pid.set_pid_gain(process_variable, actuator, gain_name, gain_value)
  end

  # def enable_integrators() do
  # end

  # def disable_integrators() do
  # end

end
