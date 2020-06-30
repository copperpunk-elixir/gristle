defmodule Configuration.Vehicle.Car.Navigation do
  require Logger

  @spec get_goals_sorter_configs() :: list()
  def get_goals_sorter_configs() do
    [
      %{
        name: {:goals, -1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:goals, 0},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:goals, 1},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yawrate: 0},
        value_type: :map
      },
      %{
        name: {:goals, 2},
        default_message_behavior: :default_value,
        default_value: %{thrust: 0, yaw: 0},
        value_type: :map
      },
      %{
        name: {:goals, 3},
        default_message_behavior: :default_value,
        default_value: %{course: 0, speed: 0},
        value_type: :map
      },
      %{
        name: {:goals, 4},
        default_message_behavior: :default_value,
        default_value: %{latitude: 0, longitude: 0, course: 0, speed: 0},
        value_type: :map
      }
    ]
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    get_goals_sorter_configs()
  end

  @spec get_vehicle_limits() :: map()
  def get_vehicle_limits() do
    %{
      vehicle_turn_rate: 0.2,
      vehicle_loiter_speed: 5,
      takeoff_speed: 45,
      climb_speed: 50,
      vehicle_agl_ground_threshold: 1.0,
      vehicle_pitch_for_climbout: 0.1745,
      vehicle_max_ground_speed: 30
    }
  end

end

