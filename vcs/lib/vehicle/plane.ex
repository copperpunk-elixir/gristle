defmodule Vehicle.Plane do
  require Logger
  alias Common.Utils.Math, as: Math
  def get_auto_pv_value_map(pv_value_map) do
    course = :math.atan2(pv_value_map.velocity.east, pv_value_map.velocity.north)
    speed = Math.hypot(pv_value_map.velocity.north, pv_value_map.velocity.east)
    altitude = pv_value_map.position.altitude
    %{course: course, speed: speed, altitude: altitude}
  end

  def start_pv_cmds_message_sorters() do
    Logger.debug("Start Plane message sorters")
    MessageSorter.System.start_link()
    Enum.each(get_process_variable_list(), fn msg_sorter_config ->
      MessageSorter.System.start_sorter(msg_sorter_config)
    end)
  end

  @spec get_process_variable_list() :: list()
  def get_process_variable_list() do
    [
      %{
        name: {:pv_cmds, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:pv_cmds, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, roll: 0, pitch: 0, yaw: 0},
        value_type: :map
      },
      %{
        name: {:pv_cmds, 3},
        default_message_behavior: :default_value,
        default_value: %{course: 0, speed: 0, altitude: 0},
        value_type: :map
      }
    ]
  end

  @spec get_control_state_config() :: map()
  def get_control_state_config() do
    %{
      name: :control_state,
      default_message_behavior: :default_value,
      default_value: 3,
      value_type: :number
    }
  end

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
        {:heading, :relative, -0.52, 0.52, 1},
        {:altitude, :relative, -2, 2, 1},
        {:speed, :absolute, 6, 12, 1}
      ]
    end
  end
end

