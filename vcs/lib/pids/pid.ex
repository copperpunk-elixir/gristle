defmodule Pids.Pid do
  use GenServer
  require Logger

  @output_min 0.0
  @output_max 1.0

  def start_link(config) do
    Logger.debug("Start PID #{inspect(config[:name])}")
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
  end

  @impl GenServer
  def init(config) do
    {process_variable, actuator} = Map.get(config, :name)
    {:ok, %{
        process_variable: process_variable,
        actuator: actuator,
        rate_or_position: config.rate_or_position,
        one_or_two_sided: config.one_or_two_sided,
        kp: Map.get(config, :kp, 0),
        ki: Map.get(config, :ki, 0),
        kd: Map.get(config, :kd, 0),
        pv_error_prev: 0,
        output: get_initial_output(config.one_or_two_sided)
      }}
  end

  @impl GenServer
  def handle_cast({:update, process_var_error, _dt}, state) do
    # Logger.debug("Update pid #{state.process_variable}/#{state.actuator}")
    cmd_p = state.kp*process_var_error
    delta_output = cmd_p
    output =
      case state.rate_or_position do
        :rate -> get_initial_output(state.one_or_two_sided) + delta_output
        :position -> state.output + delta_output
      end
    # output = Common.Utils.Math.constrain(output, @output_min, @output_max)

    {:noreply, %{state | output: output}}
  end

  @impl GenServer
  def handle_call(:get_output, _from, state) do
    {:reply, state.output, state}
  end

  def update_pid(process_variable, actuator, process_var_error, dt) do
    GenServer.cast(via_tuple(process_variable, actuator), {:update, process_var_error, dt})
  end

  def get_output(process_variable, actuator) do
    GenServer.call(via_tuple(process_variable, actuator), :get_output)
  end

  def via_tuple(process_variable, actuator) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,{process_variable, actuator})
  end

  def via_tuple({process_variable, actuator}) do
    via_tuple(process_variable, actuator)
  end

  def get_initial_output(one_or_two_sided) do
    case one_or_two_sided do
      :one_sided -> @output_min
      :two_sided -> 0.5*(@output_min + @output_max)
    end
  end
end
