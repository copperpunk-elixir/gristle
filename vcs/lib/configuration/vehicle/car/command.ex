defmodule Configuration.Vehicle.Car.Command do
  require Logger

  @spec get_commands() :: list()
  def get_commands() do
    [:throttle, :rudder, :brake, :thrust, :yawrate, :yaw, :course_ground, :speed]
  end

  @spec get_rx_output_channel_map(map(), map()) :: list()
  def get_rx_output_channel_map(output_limits, command_multipliers) do
    # channel_number, channel, absolute/relative, min, max
    relative_channels = [:course_ground]
    channel_assignments = %{
      0 => [:yawrate, :yaw, :course_ground],
      1 => [:brake],
      2 => [:thrust, :speed],
      # 7 => [:select]
    }
    frozen_channels = %{
      -1 => [:yawrate, :thrust],
      0 => [:thrust],
    }
    cs_channels = %{
      -1 => [:yawrate, :thrust, :brake],
      0 => [:yawrate, :thrust, :brake],
      1 => [:yawrate, :thrust, :brake],
      2 => [:yaw, :thrust, :brake],
      3 => [:course_ground, :speed],
      # Manual only channels
      100 => [],
      # Manual and Semi-Auto channels
      101 => [],
      # Auto only channels
      102 => []
    }
    cs_values = [-1, 0, 1, 2, 3, 100, 101, 102]
    Enum.reduce(cs_values, %{}, fn (cs, acc) ->
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
  end

  @spec get_channel_config(map(), map(), atom(), integer(), atom(), boolean()) :: tuple()
  def get_channel_config(limits, multipliers, channel_name, channel_number, rel_abs, frozen \\ false) do
    {output_min, output_mid, output_max} = if frozen do
      {0.0, 0.0, 0.0}
    else
      {get_in(limits, [channel_name, :min]), get_in(limits, [channel_name, :mid]), get_in(limits, [channel_name, :max])}
    end
    {channel_number, channel_name, rel_abs, output_min, output_mid, output_max, Map.get(multipliers, channel_name)}
  end

end
