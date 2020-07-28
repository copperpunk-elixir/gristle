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
    {:ok, %{
        process_variable: process_variable,
        control_variable: control_variable,
        kp: Map.get(config, :kp, 0),
        ki: Map.get(config, :ki, 0),
        kd: Map.get(config, :kd, 0),
        ff: Map.get(config, :ff, nil),
        output_min: config.output_min,
        output_max: config.output_max,
        correction_min: config.input_min,
        correction_max: config.input_max,
        output_neutral: config.output_neutral,
        pv_integrator: 0,
        pv_correction_prev: 0,
        output: config.output_neutral,
        feed_forward_prev: 0
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_call({:update, pv_cmd, pv_value, airspeed, dt}, _from, state) do
    # Logger.debug("update #{state.process_variable}/#{state.control_variable} with #{pv_cmd}/#{pv_value}")
    delta_output_min = state.output_min - state.output_neutral
    delta_output_max = state.output_max - state.output_neutral
    correction_raw = pv_cmd - pv_value
    {correction, out_of_range} = Common.Utils.Math.constrain?(correction_raw, state.correction_min, state.correction_max)
    pv_integrator =
      unless out_of_range do
      pv_add = correction*dt
      state.pv_integrator + pv_add
    else
      0.0
    end
    cmd_p = state.kp*correction
    |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)

    cmd_i = state.ki*pv_integrator
    |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)

    cmd_d =
    if dt != 0 do
      -state.kd*(correction_raw - state.pv_correction_prev)/dt
      |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)
    else
      0.0
    end
    delta_output = cmd_p + cmd_i + cmd_d
    feed_forward =
      case Map.get(state, :ff) do
        nil -> 0
        f -> f.(pv_value+correction, pv_value, airspeed)
      end
    # fscalculate_feed_forward(correction, state.ff_poly, state.ff_poly_degree)
    # Logger.debug("delta: #{state.process_variable}/#{state.control_variable}: #{delta_output}")
    output = state.output_neutral + feed_forward + delta_output
    # Logger.debug("corr/dt/p/i/d/total: #{correction}/#{dt}/#{cmd_p}/#{cmd_i}/#{cmd_d}/#{output}")
    output = Common.Utils.Math.constrain(output, state.output_min, state.output_max)
    if state.process_variable == :course do
      # Logger.debug("corr/p/i/d/total: #{Common.Utils.eftb(correction,3)}/#{Common.Utils.eftb(cmd_p, 3)}/#{Common.Utils.eftb(cmd_i, 3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(output, 3)}")
    end
    pv_correction_prev = correction_raw
    pv_integrator =
    if (state.ki != 0) do
      cmd_i / state.ki
    else
      0.0
    end
    # Logger.debug("post: #{state.process_variable}/#{state.control_variable}: #{output}")
    {:reply,output, %{state | output: output, feed_forward_prev: feed_forward, pv_correction_prev: pv_correction_prev, pv_integrator: pv_integrator}}
  end

  @impl GenServer
  def handle_call({:get_output, weight}, _from, state) do
    # Logger.debug("get output #{state.process_variable}/#{state.control_variable}: #{state.output}")
    {:reply, state.output*weight, state}
  end

  @impl GenServer
  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end


  def calculate_feed_forward(correction, ff_poly, ff_poly_deg) do
    Enum.reduce(ff_poly_deg..0, 0, fn (degree, acc) ->
      acc + Common.Utils.Math.integer_power(correction,degree)*Enum.at(ff_poly, ff_poly_deg - degree)
    end)
  end

  def update_pid(pv_name, output_variable_name, pv_cmd, pv_value, airspeed, dt) do
    GenServer.call(via_tuple(pv_name, output_variable_name), {:update, pv_cmd, pv_value, airspeed, dt})
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

  def get_config(process_variable_name, output_variable_name) do
    GenServer.call(via_tuple(process_variable_name, output_variable_name), :get_config)
  end
end
