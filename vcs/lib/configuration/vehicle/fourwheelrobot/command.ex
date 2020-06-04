defmodule Configuration.Vehicle.FourWheelRobot.Command do
  require Logger

  @spec get_rx_output_channel_map() :: list()
  def get_rx_output_channel_map() do
    output_limits = Configuration.Vehicle.get_command_output_limits(:FourWheelRobot, [:thrust, :yawrate, :course, :speed])

    # channel_number, channel, absolute/relative, min, max
    %{
      -1 => [
        {2, :thrust, :absolute, 0, 0, 0},
        {0, :yawrate, :absolute, 0, 0, 0}
      ],
      0 => [
        {2, :thrust, :absolute, 0, 0,0},
        {0, :yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1}
      ],
      1 => [
        {2,:thrust, :absolute, output_limits.thrust.min, output_limits.thrust.max, 1},
        {0,:yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1}
      ],
      2 => [
        {2,:thrust, :absolute, output_limits.thrust.min, output_limits.thrust.max, 1},
        {0,:yaw, :relative, output_limits.yawrate.min, output_limits.yawrate.max, 1}
      ],
      3 => [
        {0, :course, :relative, output_limits.course.min, output_limits.course.max, 1},
        {2,:speed, :relative, output_limits.speed.min, output_limits.speed.max, 1}
      ]
    }
  end
end
