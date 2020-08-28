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
        output_neutral: config.output_neutral,
        integrator_range_min: Map.get(config, :integrator_range_min, 0),
        integrator_range_max: Map.get(config, :integrator_range_max, 0),
        pv_integrator: 0,
        pv_correction_prev: 0,
        output: config.output_neutral
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
    correction = pv_cmd - pv_value
    in_range = Common.Utils.Math.in_range?(correction, state.integrator_range_min, state.integrator_range_max)
    pv_integrator =
    if in_range do
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
      -state.kd*(correction- state.pv_correction_prev)/dt
      |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)
    else
      0.0
    end
    delta_output = cmd_p + cmd_i + cmd_d
    feed_forward =
      case Map.get(state, :ff) do
        nil -> 0
        f ->
          f.(pv_value+correction, pv_value, airspeed)
          |> Common.Utils.Math.constrain(delta_output_min, delta_output_max)
      end
    # Logger.debug("delta: #{state.process_variable}/#{state.control_variable}: #{delta_output}")
    output = state.output_neutral + feed_forward + delta_output
    # Logger.debug("corr/dt/p/i/d/total: #{correction}/#{dt}/#{cmd_p}/#{cmd_i}/#{cmd_d}/#{output}")
    output = Common.Utils.Math.constrain(output, state.output_min, state.output_max)
    output = if state.process_variable == :speed do
      max_delta_output = 0.02
      delta_output = output-state.output
      |> Common.Utils.Math.constrain(-max_delta_output, max_delta_output)
      # Logger.debug("corr/p/i/d/total: #{Common.Utils.eftb(correction,3)}/#{Common.Utils.eftb(cmd_p, 3)}/#{Common.Utils.eftb(cmd_i, 3)}/#{Common.Utils.eftb(cmd_d, 3)}/#{Common.Utils.eftb(state.output+delta_output, 3)}")
      state.output + delta_output
    else
      output
    end
    # if state.process_variable == :rollrate do
    #   Logger.debug("cmd/value/corr/p/ff/total: #{Common.Utils.eftb(pv_cmd,3)}/#{Common.Utils.eftb(pv_value,3)}/#{Common.Utils.eftb(correction,3)}/#{Common.Utils.eftb(cmd_p, 3)}/#{Common.Utils.eftb(feed_forward,3)}/#{Common.Utils.eftb(output-state.output_neutral, 3)}")
    # end

    pv_correction_prev = correction
    pv_integrator =
    if (state.ki != 0) do
      cmd_i / state.ki
    else
      0.0
    end
    # Logger.debug("post: #{state.process_variable}/#{state.control_variable}: #{output}")
    {:reply,output, %{state | output: output,  pv_correction_prev: pv_correction_prev, pv_integrator: pv_integrator}}
  end

  @impl GenServer
  def handle_call({:get_output, weight}, _from, state) do
    # Logger.debug("get output #{state.process_variable}/#{state.control_variable}: #{state.output}")
    {:reply, state.output*weight, state}
  end

  @impl GenServer
  def handle_call(:get_all_parameters, _from, state) do
    output = filter_parameters(state)
    {:reply, output, state}
  end

  @impl GenServer
  def handle_call({:get_parameter, parameter}, _from, state) do
    {:reply, Map.get(state, parameter, nil), state}
  end

  @impl GenServer
  def handle_cast({:set_parameter, parameter, value}, state) do
    {:noreply, Map.put(state, parameter, value)}
  end

  @impl GenServer
  def handle_cast(:write_parameters_to_file, state) do
    output = filter_parameters(state)
    file_suffix = Atom.to_string(state.process_variable) <> "-" <> Atom.to_string(state.control_variable)
    {:ok, data} = Jason.encode(output, [pretty: true])
    Logging.Logger.write_to_folder("pid", data, file_suffix)
    {:noreply, state}
  end

  def update_pid(pv_name, output_variable_name, pv_cmd, pv_value, airspeed, dt) do
    GenServer.call(via_tuple(pv_name, output_variable_name), {:update, pv_cmd, pv_value, airspeed, dt})
  end

  def get_output(process_variable, control_variable, weight\\1) do
    GenServer.call(via_tuple(process_variable, control_variable), {:get_output, weight})
  end

  @spec via_tuple(atom(), atom()) :: tuple()
  def via_tuple(process_variable, control_variable) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,{process_variable, control_variable})
  end

  @spec via_tuple(tuple()) :: tuple()
  def via_tuple({process_variable, control_variable}) do
    via_tuple(process_variable, control_variable)
  end

  def get_all_parameters(process_variable_name, output_variable_name) do
    GenServer.call(via_tuple(process_variable_name, output_variable_name), :get_all_parameters)
  end

  @spec filter_parameters(map()) :: map()
  def filter_parameters(state) do
    Map.take(state, [:kp, :ki, :kd, :output_min, :output_max, :correction_min, :correction_max, :output_neutral])
  end

  @spec get_parameter(atom(), atom(), atom()) :: float()
  def get_parameter(process_variable_name, output_variable_name, parameter) do
    GenServer.call(via_tuple(process_variable_name, output_variable_name), {:get_parameter, parameter})
  end

  @spec set_parameter(atom(), atom(), atom(), float()) :: atom()
  def set_parameter(process_variable_name, output_variable_name, parameter, value) do
    GenServer.cast(via_tuple(process_variable_name, output_variable_name), {:set_parameter, parameter, value})
  end

  @spec write_parameters_to_file(atom(), atom()) :: atom()
  def write_parameters_to_file(process_variable_name, output_variable_name) do
    GenServer.cast(via_tuple(process_variable_name, output_variable_name), :write_parameters_to_file)
  end

   @spec set_pid_gain(atom(), atom(), atom(), float()) ::atom()
  def set_pid_gain(pv, ov, param, value) do
    msg = [pv, ov, param, value] |> Msgpax.pack!(iodata: false)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:set_pid_gain, msg)
  end

  @spec get_pid_gain(atom(), atom(), atom()) :: atom()
  def get_pid_gain(pv, ov, param) do
    msg = [pv, ov, param] |> Msgpax.pack!(iodata: false)
    Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:request_pid_gain, msg)
  end
end
