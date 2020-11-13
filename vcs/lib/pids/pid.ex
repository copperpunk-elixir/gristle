defmodule Pids.Pid do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Pids.Pid #{inspect(config[:name])} GenServer")
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: via_tuple(Keyword.fetch!(config, :name)))
    GenServer.cast(via_tuple(Keyword.fetch!(config, :name)), {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    pid_module = Module.concat(Pids.Controller, Keyword.fetch!(config, :type))
    state = apply(pid_module, :begin, [config])
    # Logger.warn("pid: #{state.process_variable}/#{state.control_variable} returned from begin")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:force_output, output}, state) do
    {:noreply, %{state | output: output}}
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

  @impl GenServer
  def handle_call({:update, pv_cmd, pv_value, airspeed, dt}, _from, state) do
    state = apply(state.pid_module, :update, [pv_cmd, pv_value, airspeed, dt, state])
    # Logger.debug("update #{state.process_variable}/#{state.control_variable} with #{pv_cmd}/#{pv_value}")
    # Logger.debug("post: #{state.process_variable}/#{state.control_variable}: #{output}")
    {:reply,state.output, state}
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

  def update_pid(pv_name, output_variable_name, pv_cmd, pv_value, airspeed, dt) do
    GenServer.call(via_tuple(pv_name, output_variable_name), {:update, pv_cmd, pv_value, airspeed, dt})
  end

  def force_output(pv_name, output_variable_name, value) do
    GenServer.cast(via_tuple(pv_name, output_variable_name), {:force_output, value})
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
    parameters = apply(state.pid_module, :parameters_to_write, [])
    Map.take(state, parameters)
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
