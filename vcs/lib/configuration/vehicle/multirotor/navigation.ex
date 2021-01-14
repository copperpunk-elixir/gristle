defmodule Configuration.Vehicle.Multirotor.Navigation do
  require Logger

  @spec goals_sorter_configs() :: list()
  def goals_sorter_configs() do
    [
      [
        name: {:goals, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
        value_type: :map,
        publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
      ],
      [
        name: {:goals, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, roll: 0.0, pitch: 0.0, yaw: 0.0},
        value_type: :map,
        publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
      ],
      [
        name: {:goals, 3},
        default_message_behavior: :default_value,
        default_value: %{course_flight: 0, speed: 0, altitude: 0},
        value_type: :map,
        publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
      ]
    ]
  end

  @spec peripheral_paths_sorter_config() :: list()
  def peripheral_paths_sorter_config() do
    [[
      name: :peripheral_paths,
      default_message_behavior: :default_value,
      default_value: nil,
      value_type: :map,
      publish_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
    ]]
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    goals_sorter_configs() ++ peripheral_paths_sorter_config()
  end

  @spec get_vehicle_limits(binary()) :: map()
  def get_vehicle_limits(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_vehicle_limits, [])
  end
end
