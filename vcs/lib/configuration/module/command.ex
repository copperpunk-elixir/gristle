defmodule Configuration.Module.Command do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, node_type) do
    %{
      commander: %{vehicle_type: vehicle_type},
    }
  end

  @spec get_command_output_limits(atom(), list()) :: tuple()
  def get_command_output_limits(vehicle_type, channels) do
    vehicle_module =
      case vehicle_type do
        :Plane ->
          model_type = Common.Utils.get_model_type()
          Module.concat(Configuration.Vehicle.Plane.Pids, model_type)
        _other ->
          Module.concat(Configuration.Vehicle, vehicle_type)
          |> Module.concat(Pids)
      end

    Enum.reduce(channels, %{}, fn (channel, acc) ->
      IO.puts("channel: #{channel}")
      constraints =
        apply(vehicle_module, :get_constraints, [])
        |> Map.get(channel)
      Map.put(acc, channel, %{min: constraints.output_min, max: constraints.output_max})
    end)
  end
end
