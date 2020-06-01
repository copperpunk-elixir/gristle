defmodule Configuration.Vehicle.Car.Command do
  require Logger

  @spec get_rx_output_channel_map(:integer) :: list()
  def get_rx_output_channel_map(control_state) do
    # channel, absolute/relative, min, max
    case control_state do
      1 -> [
        {2,:thrust, :absolute, 0, 1, 1},
        {0,:yawrate, :absolute, -0.52, 0.52, 1}
      ]
      2 -> [
        {2,:thrust, :absolute, 0, 1, 1},
        {0,:yaw, :relative, -0.52, 0.52, 1}
      ]
      3 -> [
        {0, :course, :relative, -0.52, 0.52, 1},
        {2,:speed, :absolute, 0, 10, 1}
      ]
    end
  end


end
