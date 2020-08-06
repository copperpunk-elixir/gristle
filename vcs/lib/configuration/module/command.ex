defmodule Configuration.Module.Command do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, node_type) do
    %{
      commander: %{vehicle_type: vehicle_type},
      children: get_command_children(node_type)
    }
  end

  @spec get_command_children(atom()) :: map()
  def get_command_children(node_type) do
    case node_type do
      :all ->
        [{Peripherals.Uart.FrskyRx, %{
             device_description: "Feather M0"
          }}]
      :sim ->
        [{Peripherals.Uart.FrskyRx, %{
             device_description: "Feather M0",
          }}]
      _other -> []
    end
  end

  @spec get_command_output_limits(atom(), list()) :: tuple()
  def get_command_output_limits(vehicle_type, channels) do
    vehicle_module =
      Module.concat(Configuration.Vehicle, vehicle_type)
      |> Module.concat(Pids)

    Enum.reduce(channels, %{}, fn (channel, acc) ->
      IO.puts("channel: #{channel}")
      constraints =
        apply(vehicle_module, :get_constraints, [])
        |> Map.get(channel)
      Map.put(acc, channel, %{min: constraints.output_min, max: constraints.output_max})
    end)
  end
end
