defmodule Pid.Pid do
  use GenServer
  require Logger
  @correction_rate_max 52.36 #pi/6
  @integrator_max 0.52
  @output_min 0.0
  @output_max 1.0

  def start_link(config) do
    Logger.debug("Start PID")
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
  end

  def init(config) do
    {:ok, %{
        kp: config.kp,
        ki: config.ki,
        kd: config.kd,
        rate_or_position: config.rate_or_position,
        one_or_two_sided: config.one_or_two_sided,
        integrator: 0,
        output: get_initial_output(config.one_or_two_sided),
        correction_rate_max: Map.get(config,:correction_rate_max, @correction_rate_max),
        integrator_max: Map.get(config,:integrator_max, @integrator_max),
        integrator_enabled: false
     }}
  end

  def handle_call({:update_cmd, pos_error, rate_act, dt}, _from, state) do
    # pos_error_max = @correction_rate_max
    # pos_error = Common.Utils.Math.constrain(pos_error, -pos_error_max, pos_error_max)
    rate_cmd_p = state.kp*pos_error
    {rate_cmd_i, integrator} =
    if (state.integrator_enabled) && (state.ki != 0) do
      integrator = state.integrator + pos_error*dt
      corr_i = Common.Utils.Math.constrain(state.ki*integrator, -@integrator_max, @integrator_max)
      integrator = corr_i / state.ki
      {corr_i, integrator}
    else
      {0, 0}
    end
    rate_error = (rate_cmd_p + rate_cmd_i)-rate_act
    rate_output = state.kd*rate_error
    output =
      case state.rate_or_position do
        :rate -> get_initial_output(state.one_or_two_sided) + rate_output
        :position -> state.output + rate_output
      end
    output = Common.Utils.Math.constrain(output, @output_min, @output_max)
    # error_string = :erlang.float_to_binary(Common.Utils.rad2deg(pos_error), [decimals: 2])
    # rate_error_string = :erlang.float_to_binary(Common.Utils.rad2deg(rate_error), [decimals: 2])
    # delta_output_string = :erlang.float_to_binary(delta_output, [decimals: 2])
    # output_string = :erlang.float_to_binary(output, [decimals: 2])
    # IO.puts("pos_error/rate_error/output: #{error_string}/#{rate_error_string}/#{delta_output_string}/#{output_string}")
    {:reply, output, %{state | integrator: integrator, output: output}}
  end

  def handle_call(:get_last_cmd, _from, state) do
    {:reply, state.output, state}
  end

  def handle_cast({:set_pid_gain, gain_name, gain_value}, state) do
    IO.puts("old PID: #{inspect(state)}")
    state = put_in(state, [gain_name], gain_value)
    IO.puts("new PID: #{inspect(state)}")
    {:noreply, state}
  end

  def handle_cast(:enable_integrator, state) do
    {:noreply, %{state | integrator_enabled: true}}
  end

  def handle_cast(:disable_integrator, state) do
    {:noreply, %{state | integrator_enabled: false}}
  end

  def get_cmd_for_error(process_variable, actuator, cmd_error, rate_act, dt) do
    GenServer.call(via_tuple(process_variable, actuator), {:update_cmd, cmd_error, rate_act, dt})
  end

  def get_last_cmd(process_variable, actuator) do
    GenServer.call(via_tuple(process_variable, actuator), :get_last_cmd)
  end

  def set_pid_gain(process_variable, actuator, gain_name, gain_value) do
    GenServer.cast(via_tuple(process_variable, actuator), {:set_pid_gain, gain_name, gain_value})
  end

  def enable_integrator(process_variable, actuator)do
    GenServer.cast(via_tuple(process_variable, actuator), :enable_integrator)
  end

  # def disable_integrator(channel_name) do
  #   GenServer.cast(channel_name, :disable_integrator)
  # end

  def get_initial_output(one_or_two_sided) do
    case one_or_two_sided do
      :one_sided -> @output_min
      :two_sided -> 0.5*(@output_min + @output_max)
    end
  end

  defp via_tuple(process_name, actuator) do
    Common.ProcessRegistry.via_tuple({__MODULE__, {process_name, actuator}})
  end

  defp via_tuple({process_name, actuator}) do
    Common.ProcessRegistry.via_tuple({__MODULE__, {process_name, actuator}})
  end

end
