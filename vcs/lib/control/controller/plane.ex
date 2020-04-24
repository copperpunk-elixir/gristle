defmodule Control.Controller.Plane do
  require Logger
  alias Common.Utils.Math, as: Math
  def get_auto_pv_value_map(pv_value_map) do
    heading = :math.atan2(pv_value_map.velocity.y, pv_value_map.velocity.x)
    speed = Math.hypot(pv_value_map.velocity.x, pv_value_map.velocity.y)
    altitude = pv_value_map.position.z
    %{heading: heading, speed: speed, altitude: altitude}
  end

  def start_message_sorters() do
    Logger.debug("Start Car message sorters")
    MessageSorter.System.start_link()
    Enum.each(get_process_variable_list(), fn msg_sorter_config ->
      MessageSorter.System.start_sorter(msg_sorter_config)
    end)
  end

  def get_pv_cmds_list(control_state) do
    case control_state do
      :auto -> [:heading, :speed, :altitude]
      :semi_auto -> [:roll, :pitch, :yaw]
      :manual -> [:thrust, :rollrate, :pitchrate, :yawrate]
      other -> []
    end
  end

  def get_process_variable_list() do
    [
      %{name: {:pv_cmds, :thrust}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :rollrate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :pitchrate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :yawrate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :roll}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :pitch}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :yaw}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :heading}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :speed}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :altitude}, default_message_behavior: :default_value, default_value: 0},
    ]
  end
end
