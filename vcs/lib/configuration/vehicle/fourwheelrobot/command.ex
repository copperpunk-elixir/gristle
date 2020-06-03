defmodule Configuration.Vehicle.FourWheelRobot.Command do
  require Logger

  def get_config() do
    %{
      commander: %{vehicle_type: :Car},
      frsky_rx: %{
        device_description: "Feather M0",
        publish_rx_output_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
      }
    }
  end

  @spec get_rx_output_channel_map(:integer) :: list()
  def get_rx_output_channel_map(control_state) do
    # channel, absolute/relative, min, max
    case control_state do
      -1 -> [
        {2, :thrust, :absolute, 0, 0, 0},
        {0, :yawrate, :absolute, 0, 0, 0}
      ]
      0 -> [
        {2, :thrust, :absolute, 0, 0,0},
        {0, :yawrate, :absolute, -0.52, 0.52, 1}
      ]
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
