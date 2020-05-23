defmodule Vehicle.Car do
  require Logger
  def get_auto_pv_value_map(pv_map, pv_cmds) do
    speed_corr = pv_cmds.speed - Common.Utils.Math.hypot(pv_map.velocity.x, pv_map.velocity.y)
    %{speed: speed_corr}
  end

  def start_pv_cmds_message_sorters() do
    Logger.debug("Start Car message sorters")
    MessageSorter.System.start_link()
    Enum.each(get_process_variable_map(), fn {_level, msg_sorter_config} ->
      MessageSorter.System.start_sorter(msg_sorter_config)
    end)
  end

  def get_process_variable_map() do
    %{1 => %{
        name: {:pv_cmds, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yawrate: 0},
        value_type: :map
      },
      2 => %{
        name: {:pv_cmds, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yaw: 0},
        value_type: :map
      },
      3 => %{
        name: {:pv_cmds, 3},
        default_message_behavior: :default_value,
        default_value: %{speed: 0, yaw: 0},
        value_type: :map
      }
    }
  end
end
