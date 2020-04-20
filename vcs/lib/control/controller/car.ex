defmodule Control.Controller.Car do
  require Logger
  def update_auto_pv_correction(pv_map, pv_cmds) do
    speed_corr = pv_cmds.speed - Common.Utils.Math.hypot(pv_map.velocity.x, pv_map.velocity.y)
    height_corr = pv_cmds.height - pv_map.position.z
    %{speed: speed_corr, height: height_corr}
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
      %{name: {:pv_cmds, :yaw_rate}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :speed}, default_message_behavior: :default_value, default_value: 0},
      %{name: {:pv_cmds, :steering}, default_message_behavior: :default_value, default_value: 0},
    ]
  end
end
