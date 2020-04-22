defmodule Control.Controller.Plane do
  require Logger
  def update_auto_pv_correction(pv_map, pv_cmds) do
    speed_corr = pv_cmds.speed - Common.Utils.Math.hypot(pv_map.velocity.x, pv_map.velocity.y)
    altitude_corr = pv_cmds.altitude - pv_map.position.z
    %{speed: speed_corr, altitude: altitude_corr}
  end

  def start_message_sorters() do
    Logger.debug("Start Car message sorters")
    MessageSorter.System.start_link()
    Enum.each(get_process_variable_list(), fn msg_sorter_config ->
      MessageSorter.System.start_sorter(msg_sorter_config)
    end)
  end

  def get_process_variable_list() do
    [
      %{name: {:pv_cmds, :thrust}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :roll_rate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :pitch_rate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :yaw_rate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :roll}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :pitch}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :yaw}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :heading}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :speed}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :altitude}, default_message_behavior: :default_value, default_value: 0},
    ]
  end
end
