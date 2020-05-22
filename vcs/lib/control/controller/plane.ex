defmodule Control.Controller.Plane do
  require Logger
  alias Common.Utils.Math, as: Math
  def get_auto_pv_value_map(pv_value_map) do
    heading = :math.atan2(pv_value_map.velocity.east, pv_value_map.velocity.north)
    speed = Math.hypot(pv_value_map.velocity.north, pv_value_map.velocity.east)
    altitude = pv_value_map.position.altitude
    %{heading: heading, speed: speed, altitude: altitude}
  end

  def start_pv_cmds_message_sorters() do
    Logger.debug("Start Plane message sorters")
    MessageSorter.System.start_link()
    Enum.each(get_process_variable_list(), fn msg_sorter_config ->
      MessageSorter.System.start_sorter(msg_sorter_config)
    end)
  end

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
        default_value: %{heading: 0, speed: 0, altitude: 0},
        value_type: :map
      }
    ]
  end
end
