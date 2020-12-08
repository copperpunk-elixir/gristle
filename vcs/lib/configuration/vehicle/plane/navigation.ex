defmodule Configuration.Vehicle.Plane.Navigation do
  require Logger

  @spec get_goals_sorter_configs() :: list()
  def get_goals_sorter_configs() do
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
        default_value: %{thrust: 0, roll: 0.175, pitch: 0.1, yaw: 0.09},
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

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    get_goals_sorter_configs()
  end

  @spec get_vehicle_limits(binary()) :: map()
  def get_vehicle_limits(model_type) do
    model_module = Module.concat(__MODULE__, String.to_existing_atom(model_type))
    apply(model_module, :get_vehicle_limits, [])
  end
end
