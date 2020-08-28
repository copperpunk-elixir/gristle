defmodule Configuration.Vehicle.Plane.Command do
  require Logger

  @spec get_rx_output_channel_map() :: list()
  def get_rx_output_channel_map() do
    commands = [:thrust, :rollrate, :pitchrate, :yawrate, :roll, :pitch, :yaw, :course_flight, :speed, :altitude]
    output_limits = Configuration.Module.Command.get_command_output_limits(:Plane, commands)
    command_multipliers = Configuration.Module.Command.get_command_output_multipliers(:Plane, commands)
    # channel_number, channel, absolute/relative, min, max
    %{
      -1 => [
        get_channel_config(output_limits, command_multipliers, :rollrate, 0, :absolute, true),
        get_channel_config(output_limits, command_multipliers, :pitchrate, 1, :absolute, true),
        get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute, true),
        get_channel_config(output_limits, command_multipliers, :yawrate, 3, :absolute, true)
        # {0, :rollrate, :absolute, 0, 0, 0},
        # {1, :pitchrate, :absolute, 0, 0, 0},
        # {2, :thrust, :absolute, 0, 0, 0},
        # {3, :yawrate, :absolute, 0, 0, 0}
      ],
      0 => [
        get_channel_config(output_limits, command_multipliers, :rollrate, 0, :absolute),
        get_channel_config(output_limits, command_multipliers, :pitchrate, 1, :absolute),
        get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute, true),
        get_channel_config(output_limits, command_multipliers, :yawrate, 3, :absolute)

        # {0, :rollrate, :absolute, output_limits.rollrate.min, output_limits.rollrate.max, command_multipliers.rollrate},
        # {1, :pitchrate, :absolute, output_limits.pitchrate.min, output_limits.pitchrate.max, command_multipliers.pitchrate},
        # {2, :thrust, :absolute, 0, 0, 0},
        # {3, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, command_multipliers.yawrate},
      ],
      1 => [
        get_channel_config(output_limits, command_multipliers, :rollrate, 0, :absolute),
        get_channel_config(output_limits, command_multipliers, :pitchrate, 1, :absolute),
        get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute),
        get_channel_config(output_limits, command_multipliers, :yawrate, 3, :absolute)

        # {0, :rollrate, :absolute, output_limits.rollrate.min, output_limits.rollrate.max, command_multipliers.rollrate},
        # {1, :pitchrate, :absolute, output_limits.pitchrate.min, output_limits.pitchrate.max, command_multipliers.pitchrate},
        # {2, :thrust, :absolute, 0, output_limits.thrust.max, command_multipliers.thrust},
        # {3, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, command_multipliers.yawrate},
      ],
      2 => [
        get_channel_config(output_limits, command_multipliers, :roll, 0, :absolute),
        get_channel_config(output_limits, command_multipliers, :pitch, 1, :absolute),
        get_channel_config(output_limits, command_multipliers, :thrust, 2, :absolute),
        get_channel_config(output_limits, command_multipliers, :yaw, 3, :absolute)

        # {0, :roll, :absolute, output_limits.roll.min, output_limits.roll.max, command_multipliers.roll},
        # {1, :pitch, :absolute, output_limits.pitch.min, output_limits.pitch.max, command_multipliers.pitch},
        # {2, :thrust, :absolute, 0, output_limits.thrust.max, command_multipliers.thrust},
        # {3, :yaw, :absolute, output_limits.yaw.min, output_limits.yaw.max, command_multipliers.yaw}
      ],
      3 => [
        get_channel_config(output_limits, command_multipliers, :course_flight, 0, :relative),
        get_channel_config(output_limits, command_multipliers, :altitude, 1, :relative),
        get_channel_config(output_limits, command_multipliers, :speed, 2, :absolute)

        # {0, :course_flight, :relative, output_limits.course_flight.min, output_limits.course_flight.max, command_multipliers.course_flight},
        # {1, :altitude, :relative, output_limits.altitude.min, output_limits.altitude.max, command_multipliers.altitude},
        # {2, :speed, :absolute, 0, 20, command_multipliers.speed}
      ]
    }
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
