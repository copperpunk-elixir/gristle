defmodule Configuration.Vehicle.FourWheelRobot.Navigation do
  require Logger

  def get_config() do
    %{
      navigator: %{
        vehicle_type: :Car,
        navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        default_pv_cmds_level: 3
      }
    }
  end

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

end
