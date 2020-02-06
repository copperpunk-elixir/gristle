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
    children = Enum.map(config.channels, fn {channel_name, channel} ->
      channel_config =
        %{
          name: channel_name,
          kp: channel.kp,
          ki: channel.ki,
          kd: channel.kd,
          rate_or_position: channel.rate_or_position,
          one_or_two_sided: channel.one_or_two_sided
        }
      Supervisor.child_spec({Pid.Pid, channel_config}, id: channel_name)
    end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def update_pid(channel_name, cmd_error, euler_rate, dt, caller) do
    output = Pid.Pid.get_cmd_for_error(channel_name, cmd_error, euler_rate, dt)
    # Return the output to the original caller (Gimbal.System)
    GenServer.cast(caller, {:pid_updated, channel_name, output})
  end

  def set_pid_gain(channel_name, gain_name, gain_value) do
    Logger.debug("update pid for #{channel_name}")
    Pid.Pid.set_pid_gain(channel_name, gain_name, gain_value)
  end

  # def enable_integrators() do
  # end

  # def disable_integrators() do
  # end

end
