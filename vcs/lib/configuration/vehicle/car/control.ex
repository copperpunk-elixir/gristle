defmodule Configuration.Vehicle.Car.Control do
  require Logger

  def get_auto_pv_value_map(pv_value_map, yaw) do
    {speed, course} = Common.Utils.get_speed_course_for_velocity(pv_value_map.velocity.north, pv_value_map.velocity.east, 2, yaw)
    %{course: course, speed: speed}
  end

  # ----- Message Sorters -----

  @spec get_pv_cmds_sorter_configs() :: list()
  def get_pv_cmds_sorter_configs() do
    [
      %{
        name: {:pv_cmds, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0,  yawrate: 0},
        value_type: :map
      },
      %{
        name: {:pv_cmds, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yaw: 0},
        value_type: :map
      },
      %{
        name: {:pv_cmds, 3},
        default_message_behavior: :default_value,
        default_value: %{course: 0, speed: 0},
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

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    get_pv_cmds_sorter_configs()
    |> Enum.concat([get_control_state_config()])
  end
end
