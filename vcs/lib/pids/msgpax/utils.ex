defmodule Pids.Msgpax.Utils do
  @spec unpack(atom(), binary()) :: any()
  def unpack(msg_type, msg) do
    case msg_type do
      :set_pid_gain -> unpack_set_pid_gain(msg)
      :request_pid_gain -> unpack_request_pid_gain(msg)
      :get_pid_gain -> unpack_get_pid_gain(msg)
    end
  end

  @spec unpack_set_pid_gain(binary()) :: list()
  def unpack_set_pid_gain(msg) do
    [process_variable, output_variable, parameter, value] = Msgpax.unpack!(msg)
    process_variable = String.to_atom(process_variable)
    output_variable = String.to_atom(output_variable)
    parameter = String.to_atom(parameter)
    [process_variable, output_variable, parameter, value]
  end

  @spec unpack_request_pid_gain(binary()) :: list()
  def unpack_request_pid_gain(msg) do
    [process_variable, output_variable, parameter] = Msgpax.unpack!(msg)
    process_variable = String.to_atom(process_variable)
    output_variable = String.to_atom(output_variable)
    parameter = String.to_atom(parameter)
    [process_variable, output_variable, parameter]
  end

  @spec unpack_get_pid_gain(binary()) :: list()
  def unpack_get_pid_gain(msg) do
    [process_variable, output_variable, parameter, value] = Msgpax.unpack!(msg)
    process_variable = String.to_atom(process_variable)
    output_variable = String.to_atom(output_variable)
    parameter = String.to_atom(parameter)
    [process_variable, output_variable, parameter, value]
  end
end
