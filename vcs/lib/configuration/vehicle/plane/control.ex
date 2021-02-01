defmodule Configuration.Vehicle.Plane.Control do
  require Logger

  def get_auto_pv_value_map(pv_value_map, yaw) do
    # course = :math.atan2(pv_value_map.velocity.east, pv_value_map.velocity.north)
    # speed = Common.Utils.Math.hypot(pv_value_map.velocity.north, pv_value_map.velocity.east)
    {speed, course} = Common.Utils.Motion.get_speed_course_for_velocity(pv_value_map.velocity.north, pv_value_map.velocity.east, 2, yaw)
    altitude = pv_value_map.position.altitude
    %{course: course, speed: speed, altitude: altitude}
  end

# ----- Message Sorters -----

  @spec get_pv_cmds_sorter_configs() :: list()
  def get_pv_cmds_sorter_configs() do
    [
      [
        name: {:pv_cmds, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
        value_type: :map,
        publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
      ],
      [
        name: {:pv_cmds, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, roll: 0.175, pitch: 0.05, yaw: 0.09},
        value_type: :map,
        publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
      ],
      [
        name: {:pv_cmds, 3},
        default_message_behavior: :default_value,
        default_value: %{course_flight: 0, speed: 0, altitude: 0},
        value_type: :map,
        publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
      ]
    ]
  end

  @spec get_control_state_config() :: map()
  def get_control_state_config() do
    [
      name: :control_state,
      default_message_behavior: :default_value,
      default_value: 2,
      value_type: :number,
      publish_interval_ms: 100
    ]
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    get_pv_cmds_sorter_configs()
    |> Enum.concat([get_control_state_config()])
  end

end
