defmodule Configuration.Vehicle.FourWheelRobot.Pids do
  @spec get_config() :: map()
  def get_config() do
    constraints = %{
      front_right: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.5},
      rear_right: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.5},
      rear_left: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.5},
      front_left: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.5},
      yawrate: %{output_min: -1.5, output_max: 1.5, output_neutral: 0},
      yaw: %{output_min: -0.2, output_max: 0.2, output_neutral: 0.0},
      thrust: %{output_min: 0, output_max: 1, output_neutral: 0}
    }

    pids = %{
      yawrate: %{
        front_right: Map.merge(%{kp: -0.5, weight: 0.25}, constraints.front_right),
        rear_right: Map.merge(%{kp: -0.5, weight: 0.25}, constraints.rear_right),
        rear_left: Map.merge(%{kp: 0.5, weight: 0.25}, constraints.rear_left),
        front_left: Map.merge(%{kp: 0.5, weight: 0.25}, constraints.front_left),
      },
      thrust: %{
        front_right: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.front_right),
        rear_right: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.rear_right),
        rear_left: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.rear_left),
        front_left: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.front_left),
      },
      yaw: %{yawrate: Map.merge(%{kp: 3.0}, constraints.yawrate)},
      course: %{yaw: Map.merge(%{kp: 0.1}, constraints.yaw)},
      speed: %{thrust: Map.merge(%{kp: 0.1, weight: 1.0}, constraints.thrust)}
    }

    %{
      pids: pids,
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
  end
end
