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
        {0, :rollrate, :absolute, 0, 0, 0},
        {1, :pitchrate, :absolute, 0, 0, 0},
        {2, :thrust, :absolute, 0, 0, 0},
        {3, :yawrate, :absolute, 0, 0, 0}
      ],
      0 => [
        {0, :rollrate, :absolute, output_limits.rollrate.min, output_limits.rollrate.max, command_multipliers.rollrate},
        {1, :pitchrate, :absolute, output_limits.pitchrate.min, output_limits.pitchrate.max, command_multipliers.pitchrate},
        {2, :thrust, :absolute, 0, 0, 0},
        {3, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, command_multipliers.yawrate},
      ],
      1 => [
        {0, :rollrate, :absolute, output_limits.rollrate.min, output_limits.rollrate.max, command_multipliers.rollrate},
        {1, :pitchrate, :absolute, output_limits.pitchrate.min, output_limits.pitchrate.max, command_multipliers.pitchrate},
        {2, :thrust, :absolute, 0, output_limits.thrust.max, command_multipliers.thrust},
        {3, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, command_multipliers.yawrate},
      ],
      2 => [
        {0, :roll, :absolute, output_limits.roll.min, output_limits.roll.max, command_multipliers.roll},
        {1, :pitch, :absolute, output_limits.pitch.min, output_limits.pitch.max, command_multipliers.pitch},
        {2, :thrust, :absolute, 0, output_limits.thrust.max, command_multipliers.thrust},
        {3, :yaw, :absolute, output_limits.yaw.min, output_limits.yaw.max, command_multipliers.yaw}
      ],
      3 => [
        {0, :course_flight, :relative, output_limits.course_flight.min, output_limits.course_flight.max, command_multipliers.course_flight},
        {1, :altitude, :relative, output_limits.altitude.min, output_limits.altitude.max, command_multipliers.altitude},
        {2, :speed, :absolute, 0, 20, command_multipliers.speed}
      ]
    }
  end


end
