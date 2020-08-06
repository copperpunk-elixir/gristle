defmodule Configuration.Vehicle.Plane.Command do
  require Logger

  @spec get_rx_output_channel_map() :: list()
  def get_rx_output_channel_map() do
    output_limits = Configuration.Module.Command.get_command_output_limits(:Plane, [:thrust, :rollrate, :pitchrate, :yawrate, :roll, :pitch, :yaw, :course_flight, :speed, :altitude])
    # channel_number, channel, absolute/relative, min, max
    %{
      -1 => [
        {0, :rollrate, :absolute, 0, 0, 0},
        {1, :pitchrate, :absolute, 0, 0, 0},
        {2, :thrust, :absolute, 0, 0, 0},
        {3, :yawrate, :absolute, 0, 0, 0}
      ],
      0 => [
        {0, :rollrate, :absolute, output_limits.rollrate.min, output_limits.rollrate.max, -1},
        {1, :pitchrate, :absolute, output_limits.pitchrate.min, output_limits.pitchrate.max, -1},
        {2, :thrust, :absolute, 0, 0, 0},
        {3, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1},
      ],
      1 => [
        {0, :rollrate, :absolute, output_limits.rollrate.min, output_limits.rollrate.max, -1},
        {1, :pitchrate, :absolute, output_limits.pitchrate.min, output_limits.pitchrate.max, -1},
        {2, :thrust, :absolute, 0, output_limits.thrust.max, 1},
        {3, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1},
      ],
      2 => [
        {0, :roll, :absolute, output_limits.roll.min, output_limits.roll.max, -1},
        {1, :pitch, :absolute, output_limits.pitch.min, output_limits.pitch.max, -1},
        {2, :thrust, :absolute, 0, output_limits.thrust.max, 1},
        {3, :yaw, :absolute, output_limits.yaw.min, output_limits.yaw.max, 1}
      ],
      3 => [
        {0, :course_flight, :relative, output_limits.course_flight.min, output_limits.course_flight.max, -1},
        {1, :altitude, :relative, output_limits.altitude.min, output_limits.altitude.max, -1},
        {2, :speed, :absolute, 0, 20, 1}
      ]
    }
  end


end
