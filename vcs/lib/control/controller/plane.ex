defmodule Control.Controller.Plane do
  require Logger
  alias Common.Utils.Math, as: Math
  def update_auto_pv_correction(pv_map, pv_cmds) do
    heading = :math.atan2(pv_map.velocity.y, pv_map.velocity.x)
    heading_corr = (pv_cmds.heading - heading)
    Logger.debug("heading_cmd/act/corr: #{Math.rad2deg(pv_cmds.heading)}/#{Math.rad2deg(heading)}/#{Math.rad2deg(heading_corr)}")
    speed_corr = pv_cmds.speed - Math.hypot(pv_map.velocity.x, pv_map.velocity.y)
    altitude_corr = pv_cmds.altitude - pv_map.position.z
    pv_corrections = %{speed: speed_corr, heading: heading_corr, altitude: altitude_corr}
    # pv_feed_forward = %{speed: %{thrust: 0.1}, altitude: %{thrust: 0.05, pitch: 0.01}}
    pv_feed_forward = %{}
    {pv_corrections, pv_feed_forward}
  end

  def update_semi_auto_pv_correction(pv_map, pv_cmds) do
    roll_corr = pv_cmds.roll - pv_map.roll
    pitch_corr = pv_cmds.pitch - pv_map.pitch
    yaw_corr = pv_cmds.yaw - pv_map.yaw
    pv_corrections = %{roll: roll_corr, pitch: pitch_corr, yaw: yaw_corr}
    pv_feed_forward = %{}
    {pv_corrections, pv_feed_forward}
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
