defmodule Pids.Pid do
  use Agent
  require Logger

  def start_link(config) do
    Logger.debug("Start Pids.Pid Agent #{inspect(config[:name])}")
    pid_module = Module.concat(Pids.Controller, Keyword.fetch!(config, :type))
    state = apply(pid_module, :begin, [config])
    Common.Utils.start_link_singular(Agent, __MODULE__, state, via_tuple(Keyword.fetch!(config, :name)))
  end

  def update_pid(pv_name, output_variable_name, pv_cmd, pv_value, airspeed, dt) do
    Agent.get_and_update(via_tuple(pv_name, output_variable_name), &update(&1, pv_cmd, pv_value, airspeed, dt))
  end

  def update(state, pv_cmd, pv_value, airspeed, dt) do
    state = apply(state.pid_module, :update, [pv_cmd, pv_value, airspeed, dt, state])
    {state.output, state}
  end

  @spec via_tuple(binary(), binary()) :: tuple()
  def via_tuple(process_variable, control_variable) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,{process_variable, control_variable})
  end

  def get_all_parameters(process_variable_name, output_variable_name) do
    Agent.get(via_tuple(process_variable_name, output_variable_name), fn state -> state end)
    |> filter_parameters()
  end

  @spec get_parameter(atom(), atom(), atom()) :: float()
  def get_parameter(process_variable_name, output_variable_name, parameter) do
    Agent.get(via_tuple(process_variable_name, output_variable_name), fn state -> state end)
    |> Map.get(parameter, nil)
  end

  @spec set_parameter(atom(), atom(), atom(), float()) :: atom()
  def set_parameter(process_variable_name, output_variable_name, parameter, value) do
    Agent.update(via_tuple(process_variable_name, output_variable_name), fn state -> Map.put(state, parameter, value) end)
  end

  @spec write_parameters_to_file(atom(), atom()) :: atom()
  def write_parameters_to_file(process_variable_name, output_variable_name) do
    state = Agent.get(via_tuple(process_variable_name, output_variable_name), fn state -> state end)
    output = filter_parameters(state)
    file_suffix = Atom.to_string(state.process_variable) <> "-" <> Atom.to_string(state.control_variable)
    {:ok, data} = Jason.encode(output, [pretty: true])
    Logging.Logger.write_to_folder("pid", data, file_suffix)
  end

  @spec filter_parameters(map()) :: map()
  def filter_parameters(state) do
    parameters = apply(state.pid_module, :parameters_to_write, [])
    Map.take(state, parameters)
  end

  @spec via_tuple(tuple()) :: tuple()
  def via_tuple({process_variable, control_variable}) do
    via_tuple(process_variable, control_variable)
  end

  #  @spec set_pid_gain(atom(), atom(), atom(), float()) ::atom()
  # def set_pid_gain(pv, ov, param, value) do
  #   msg = [pv, ov, param, value] |> Msgpax.pack!(iodata: false)
  #   Peripherals.Uart.Generic.construct_and_send_proto_message(:set_pid_gain, msg, Telemetry)
  # end

  # @spec get_pid_gain(atom(), atom(), atom()) :: atom()
  # def get_pid_gain(pv, ov, param) do
  #   msg = [pv, ov, param] |> Msgpax.pack!(iodata: false)
  #   Peripherals.Uart.Generic.construct_and_send_proto_message(:request_pid_gain, msg, Telemetry)
  # end
end
