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
        {2,:thrust, :absolute, 0, output_limits.thrust.max, 1},
        {0,:yawrate, :absolute, output_limits.yawrate.min, output_limits.yawrate.max, 1}
      ],
      2 => [
        {2,:thrust, :absolute, 0, output_limits.thrust.max, 1},
        {0,:yaw, :relative, output_limits.yawrate.min, output_limits.yawrate.max, 1}
      ],
      3 => [
        {0, :course, :relative, output_limits.course.min, output_limits.course.max, 1},
        {2,:speed, :absolute, 0, 5, 1}
      ]
    }
  end
end
