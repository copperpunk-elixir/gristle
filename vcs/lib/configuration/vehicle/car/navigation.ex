defmodule Configuration.Vehicle.Car.Navigation do
  require Logger

  @spec get_goals_sorter_default_values() :: map()
  def get_goals_sorter_default_values() do
    %{
      1 => %{thrust: 0, yawrate: 0, brake: 0.25},
      2 => %{thrust: 0, yaw: 0},
      3 => %{course_ground: 0, speed: 0}
    }
  end
end
