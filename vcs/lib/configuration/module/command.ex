defmodule Configuration.Module.Command do
  require Logger

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    rx_output_channel_map = get_rx_output_channel_map(model_type)
    [
      commander: [
        rx_output_channel_map: rx_output_channel_map
      ]
    ]
  end

  @spec get_command_output_limits(binary(), binary(), list()) :: map()
  def get_command_output_limits(model_type, vehicle_type, commands) do
    model_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    |> Module.concat(Pids)
    |> Module.concat(String.to_existing_atom(model_type))

    Enum.reduce(commands, %{}, fn (channel, acc) ->
      Logger.warn("#{channel}")
      constraints =
        apply(model_module, :get_constraints, [])
        |> Keyword.get(channel)
      # Logger.warn(inspect(constraints))
      mid = Keyword.get(constraints, :output_mid, constraints[:output_neutral])
      Map.put(acc, channel, %{min: constraints[:output_min], mid: mid, max: constraints[:output_max]})
    end)
  end

  @spec get_command_output_multipliers(binary(), binary()) :: map()
  def get_command_output_multipliers(model_type, vehicle_type) do
    vehicle_module = Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
    command_module = Module.concat(vehicle_module, Command)
    actuation_module = Module.concat(vehicle_module, Actuation)

    reversed_actuators = apply(Module.concat(actuation_module, model_type), :get_reversed_actuators, [])
    all_commands_and_related_actuators = apply(command_module, :get_all_commands_and_related_actuators, [])
    Enum.reduce(all_commands_and_related_actuators, %{}, fn ({command, actuator}, acc) ->
      mult =  if Enum.member?(reversed_actuators, actuator), do: -1, else: 1
      Map.put(acc, command, mult)
    end)
  end

  @spec get_rx_output_channel_map(binary()) :: map()
  def get_rx_output_channel_map(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module = Module.concat([Configuration.Vehicle, String.to_existing_atom(vehicle_type),Command])
    commands = apply(vehicle_module, :get_commands, [])
    output_limits = get_command_output_limits(model_type, vehicle_type, commands)
    command_multipliers = get_command_output_multipliers(model_type, vehicle_type)
    relative_channels = apply(vehicle_module, :get_relative_channels, [])
    actuation_channel_assignments = apply(vehicle_module, :get_actuation_channel_assignments, [])
    command_channel_assignments = apply(vehicle_module, :get_command_channel_assignments, [])

    Enum.reduce(command_channel_assignments, %{}, fn ({cs, command_channels}, acc) ->
      all_channels_config =
        Enum.reduce(actuation_channel_assignments, [], fn ({ch_num, actuation_channels}, acc2) ->
          all_chs = command_channels ++ actuation_channels
          # Find the channels that match between Actuation and Command for a given CS
          shared_channels = all_chs -- Enum.uniq(all_chs)
          if Enum.empty?(shared_channels) do
            acc2
          else
            channel_name = Enum.at(shared_channels, 0)
            relative_or_absolute = if Enum.member?(relative_channels, channel_name), do: :relative, else: :absolute
            ch_config = get_channel_config(Map.get(output_limits, channel_name), Map.get(command_multipliers, channel_name), channel_name, ch_num, relative_or_absolute)
            acc2 ++ [ch_config]
          end
        end)
      Map.put(acc, cs, all_channels_config)
    end)

  end

  @spec get_channel_config(map(), atom(), atom(), integer(), atom()) :: tuple()
  def get_channel_config(limits, multiplier, channel_name, channel_number, rel_abs) do
    {channel_number, channel_name, rel_abs, limits.min, limits.mid, limits.max, multiplier}
  end
end
