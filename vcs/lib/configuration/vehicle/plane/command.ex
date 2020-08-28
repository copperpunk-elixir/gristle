defmodule Configuration.Vehicle.Plane.Command do
  require Logger

  @spec get_rx_output_channel_map() :: list()
  def get_rx_output_channel_map() do
    commands = [:thrust, :rollrate, :pitchrate, :yawrate, :roll, :pitch, :yaw, :course_flight, :speed, :altitude]
    output_limits = Configuration.Module.Command.get_command_output_limits(:Plane, commands)
    command_multipliers = Configuration.Module.Command.get_command_output_multipliers(:Plane, commands)
    # channel_number, channel, absolute/relative, min, max
    relative_channels = [:course_flight, :altitude]
    channel_assignments = %{
      0 => [:rollrate, :roll, :course_flight],
      1 => [:pitchrate, :pitch, :altitude],
      2 => [:thrust, :speed],
      3 => [:yawrate, :yaw]
    }
    frozen_channels = %{
      -1 => [:rollrate, :pitchrate, :yawrate, :thrust],
      0 => [:thrust],
    }
    cs_channels = %{
      -1 => [:rollrate, :pitchrate, :yawrate, :thrust],
      0 => [:rollrate, :pitchrate, :yawrate, :thrust],
      1 => [:rollrate, :pitchrate, :yawrate, :thrust],
      2 => [:roll, :pitch, :yaw, :thrust],
      3 => [:course_flight, :speed, :altitude]
    }
    Enum.reduce(-1..3, %{}, fn (cs, acc) ->
      channels = Map.get(cs_channels, cs)
      ch_config =
        Enum.reduce(channel_assignments, [], fn ({ch_num, chs}, acc2) ->
          all_chs = channels ++ chs
          # Logger.debug("all ch: #{inspect(all_chs)}")
          output = all_chs -- Enum.uniq(all_chs)
          if Enum.empty?(output) do
            acc2
          else
            output = Enum.at(output, 0)
            relative_or_absolute = if Enum.member?(relative_channels, output), do: :relative, else: :absolute
            frozen_chs = Map.get(frozen_channels, cs, [])
            frozen = Enum.member?(frozen_chs, output)
            ch_config = get_channel_config(output_limits, command_multipliers, output, ch_num, relative_or_absolute, frozen)
            acc2 ++ [ch_config]
          end
        end)
      Map.put(acc, cs, ch_config)
    end)
    # %{
    #   -1 =>
    #     channels =
    #     [
    #     get_channel_config(output_limits, command_multipliers, :rollrate, 0, :absolute, true),
    #     get_channel_config(output_limits, command_multipliers, :pitchrate, 1, :absolute, true),
    #     get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute, true),
    #     get_channel_config(output_limits, command_multipliers, :yawrate, 3, :absolute, true)
    #   ],
    #   0 => [
    #     get_channel_config(output_limits, command_multipliers, :rollrate, 0, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :pitchrate, 1, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute, true),
    #     get_channel_config(output_limits, command_multipliers, :yawrate, 3, :absolute)
    #   ],
    #   1 => [
    #     get_channel_config(output_limits, command_multipliers, :rollrate, 0, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :pitchrate, 1, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :yawrate, 3, :absolute)
    #   ],
    #   2 => [
    #     get_channel_config(output_limits, command_multipliers, :roll, 0, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :pitch, 1, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute),
    #     get_channel_config(output_limits, command_multipliers, :yaw, 3, :absolute)

    #   ],
    #   3 => [
    #     get_channel_config(output_limits, command_multipliers, :course_flight, 0, :relative),
    #     get_channel_config(output_limits, command_multipliers, :altitude, 1, :relative),
    #     get_channel_config(output_limits, command_multipliers, :speed, 2, :absolute)

    #   ]
    # }
  end

  @spec get_channel_config(map(), map(), atom(), integer(), atom(), boolean()) :: tuple()
  def get_channel_config(limits, multipliers, channel_name, channel_number, type, frozen \\ false) do
    {output_min, output_max} = if frozen do
      {0.0, 0.0}
    else
      {get_in(limits, [channel_name, :min]), get_in(limits, [channel_name, :max])}
    end
    {channel_number, channel_name, type, output_min, output_max, Map.get(multipliers, channel_name)}
  end

end
