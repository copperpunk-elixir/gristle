defmodule Pids.Pid do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PID #{inspect(config[:name])}")
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
  end

  @impl GenServer
  def init(config) do
    {process_variable, actuator} = Map.get(config, :name)
    output_min = Map.get(config, :output_min, 0)
    output_max = Map.get(config, :output_max, 1)
    output_neutral = Map.get(config, :output_neutral, 0.5)

    {:ok, %{
        process_variable: process_variable,
        actuator: actuator,
        rate_or_position: config.rate_or_position,
        one_or_two_sided: config.one_or_two_sided,
        kp: Map.get(config, :kp, 0),
        ki: Map.get(config, :ki, 0),
        kd: Map.get(config, :kd, 0),
        output_min: output_min,
        output_max: output_max,
        output_neutral: Map.get(config, :output_neutral, 0.5),
        pv_correction_prev: 0,
        output: get_initial_output(config.one_or_two_sided, output_min, output_neutral)
      }}
  end

  @impl GenServer
  def handle_cast({:update, process_var_correction, _dt}, state) do
    # Logger.debug("update #{state.process_variable}/#{state.actuator} with #{process_var_correction}")
    cmd_p = state.kp*process_var_correction
    delta_output = cmd_p
    output =
      case state.rate_or_position do
        :rate -> get_initial_output(state.one_or_two_sided, state.output_min, state.output_neutral) + delta_output
        :position -> state.output + delta_output
      end
    output = Common.Utils.Math.constrain(output, state.output_min, state.output_max)

    {:noreply, %{state | output: output}}
  end

  @impl GenServer
  def handle_call(:get_output, _from, state) do
    {:reply, state.output, state}
  end

  def update_pid(process_variable, actuator, process_var_correction, dt) do
    GenServer.cast(via_tuple(process_variable, actuator), {:update, process_var_correction, dt})
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

  def get_initial_output(one_or_two_sided, output_min, output_neutral) do
    case one_or_two_sided do
      :one_sided -> output_min
      :two_sided -> output_neutral
    end
  end
end
