defmodule Configuration.Vehicle.Plane.Command do
  require Logger

  @spec get_rx_output_channel_map(:integer) :: list()
  def get_rx_output_channel_map(control_state) do
    # channel, absolute/relative, min, max
    case control_state do
      1 -> [
        {:rollrate, :absolute, -1.05, 1.05, 1},
        {:pitchrate, :absolute, -0.52, 0.52, -1},
        {:thrust, :absolute, 0, 1, 1},
        {:yawrate, :absolute, -0.52, 0.52, 1}
      ]
      2 -> [
        {:roll, :absolute, -0.785, 0.785, 1},
        {:pitch, :absolute, -0.785, 0.785, -1},
        {:thrust, :absolute, 0, 1, 1},
        {:yaw, :relative, -0.52, 0.52, 1}
      ]
      3 -> [
        {:course, :relative, -0.52, 0.52, 1},
        {:altitude, :relative, -2, 2, 1},
        {:speed, :absolute, 6, 12, 1}
      ]
    end
  end


end
