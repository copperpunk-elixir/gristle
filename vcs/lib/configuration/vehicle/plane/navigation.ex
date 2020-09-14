defmodule Configuration.Vehicle.Plane.Navigation do
  require Logger

  @spec get_goals_sorter_configs() :: list()
  def get_goals_sorter_configs() do
    [
      %{
        name: {:goals, -1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:goals, 0},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:goals, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, rollrate: 0, pitchrate: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:goals, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, roll: 0.26, pitch: 0.05, yaw: 0.09},
        value_type: :map
      },
      %{
        name: {:goals, 3},
        default_message_behavior: :default_value,
        default_value: %{course_flight: 0, speed: 0, altitude: 0},
        value_type: :map
      }
    ]
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    get_goals_sorter_configs()
  end

  @spec get_vehicle_limits(atom()) :: map()
  def get_vehicle_limits(model_type) do
    model_module = Module.concat(__MODULE__, model_type)
    apply(model_module, :get_vehicle_limits, [])
  end
end
