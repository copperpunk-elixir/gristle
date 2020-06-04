defmodule Configuration.Vehicle.Car.Command do
  require Logger

  @spec get_rx_output_channel_map() :: map()
  def get_rx_output_channel_map() do
    # channel, absolute/relative, min, max
    {thrust_min, thrust_max} = get_output_limits(:thrust)
    {yawrate_min, yawrate_max} = get_output_limits(:yawrate)
    {course_min, course_max} = get_output_limits(:course)
    {speed_min, speed_max} = get_output_limits(:speed)
    %{
      -1 => [
        {2, :thrust, :absolute, 0, 0, 0},
        {0, :yawrate, :absolute, 0, 0, 0}
      ],
      0 => [
        {2, :thrust, :absolute, 0, 0,0},
        {0, :yawrate, :absolute, yawrate_min, yawrate_max, 1}
      ],
      1 => [
        {2,:thrust, :absolute, thrust_min, thrust_max, 1},
        {0,:yawrate, :absolute, yawrate_min, yawrate_max, 1}
      ],
      2 => [
        {2,:thrust, :absolute, thrust_min, thrust_max, 1},
        {0,:yaw, :relative, yawrate_min, yawrate_max, 1}
      ],
      3 => [
        {0, :course, :relative, course_min, course_max, 1},
        {2,:speed, :relative, speed_min, speed_max, 1}
      ]
    }
  end

  @spec get_output_limits(atom()) :: tuple()
  def get_output_limits(channel) do
    constraints =
      Configuration.Vehicle.Car.Pids.get_constraints()
      |> Map.get(channel)
    {constraints.output_min, constraints.output_max}
  end



end
