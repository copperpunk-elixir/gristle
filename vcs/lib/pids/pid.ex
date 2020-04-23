defmodule Pids.Pid do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start PID #{inspect(config[:name])}")
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
  end

  @impl GenServer
  def init(config) do
    {process_variable, control_variable} = Map.get(config, :name)
    output_min = Map.get(config, :output_min, 0)
    output_max = Map.get(config, :output_max, 1)
    output_neutral = Map.get(config, :output_neutral, 0.5)

    {:ok, %{
        process_variable: process_variable,
        control_variable: control_variable,
        rate_or_position: config.rate_or_position,
        one_or_two_sided: config.one_or_two_sided,
        kp: Map.get(config, :kp, 0),
        ki: Map.get(config, :ki, 0),
        kd: Map.get(config, :kd, 0),
        output_min: output_min,
        output_max: output_max,
        output_neutral: Map.get(config, :output_neutral, 0.5),
        pv_correction_prev: 0,
        output: get_initial_output(config.one_or_two_sided, output_min, output_neutral),
        feed_forward_prev: 0
     }}
  end

  @impl GenServer
  def handle_cast({:update, process_var_correction, process_var_feed_forward, _dt}, state) do
    # Logger.debug("update #{state.process_variable}/#{state.control_variable} with #{process_var_correction}/#{process_var_feed_forward}")
    cmd_p = state.kp*process_var_correction
    delta_output = cmd_p
    # Logger.debug("delta: #{state.process_variable}/#{state.control_variable}: #{delta_output}")
    output =
      case state.rate_or_position do
        :rate -> get_initial_output(state.one_or_two_sided, state.output_min, state.output_neutral) + process_var_feed_forward + delta_output
        :position ->
          # Don't want FF to accumulate
          state.output + (process_var_feed_forward - state.feed_forward_prev) + delta_output
      end
    # Logger.debug("initial: #{state.process_variable}/#{state.control_variable}: #{get_initial_output(state.one_or_two_sided, state.output_min, state.output_neutral)}")
    # Logger.debug("pre: #{state.process_variable}/#{state.control_variable}: #{output}")
    output = Common.Utils.Math.constrain(output, state.output_min, state.output_max)
    # Logger.debug("post: #{state.process_variable}/#{state.control_variable}: #{output}")
    {:noreply, %{state | output: output, feed_forward_prev: process_var_feed_forward}}
  end

  @impl GenServer
  def handle_call({:get_output, weight}, _from, state) do
    {:reply, state.output*weight, state}
  end


  def update_pid(process_variable, control_variable, process_var_correction, process_var_feed_forward, dt) do
    GenServer.cast(via_tuple(process_variable, control_variable), {:update, process_var_correction, process_var_feed_forward, dt})
  end

  def get_output(process_variable, control_variable, weight\\1) do
    GenServer.call(via_tuple(process_variable, control_variable), {:get_output, weight})
  end

  def via_tuple(process_variable, control_variable) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,{process_variable, control_variable})
  end

  def via_tuple({process_variable, control_variable}) do
    via_tuple(process_variable, control_variable)
  end

  def get_initial_output(one_or_two_sided, output_min, output_neutral) do
    case one_or_two_sided do
      :one_sided -> output_min
      :two_sided -> output_neutral
    end
  end

end
