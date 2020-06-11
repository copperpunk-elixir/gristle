defmodule Configuration.Vehicle.FourWheelRobot.Pids do
  @spec get_config() :: map()
  def get_config() do
    constraints = get_constraints()

    pids = %{
      yawrate: %{
        front_right: Map.merge(%{kp: -0.5, weight: 0.25}, constraints.front_right),
        rear_right: Map.merge(%{kp: -0.5, weight: 0.25}, constraints.rear_right),
        rear_left: Map.merge(%{kp: 0.5, weight: 0.25}, constraints.rear_left),
        front_left: Map.merge(%{kp: 0.5, weight: 0.25}, constraints.front_left),
        left_direction: Map.merge(%{kp: 0.5, weight: 0.5}, constraints.left_direction),
        right_direction: Map.merge(%{kp: -0.5, weight: 0.5}, constraints.right_direction)
      },
      thrust: %{
        front_right: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.front_right),
        rear_right: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.rear_right),
        rear_left: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.rear_left),
        front_left: Map.merge(%{kp: 0.5, weight: 0.75}, constraints.front_left),
        left_direction: Map.merge(%{kp: 0.5, weight: 0.5}, constraints.left_direction),
        right_direction: Map.merge(%{kp: 0.5, weight: 0.5}, constraints.right_direction)
      },
      yaw: %{yawrate: Map.merge(%{kp: 3.0}, constraints.yawrate)},
      course: %{yaw: Map.merge(%{kp: 0.1}, constraints.yaw)},
      speed: %{thrust: Map.merge(%{kp: 0.1, weight: 1.0}, constraints.thrust)}
    }

    pids = Configuration.Vehicle.add_pid_input_constraints(pids, constraints)

    %{
      pids: pids,
      actuator_cmds_msg_classification: [0,1],
      pv_cmds_msg_classification: [0,1]
    }
  end

  @spec get_constraints() :: map()
  def get_constraints() do
    %{
      front_right: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.0},
      rear_right: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.0},
      rear_left: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.0},
      front_left: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.0},
      left_direction: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.5},
      right_direction: %{output_min: 0.0, output_max: 1.0, output_neutral: 0.5},
      yawrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      yaw: %{output_min: -0.52, output_max: 0.52, output_neutral: 0.0},
      thrust: %{output_min: -1, output_max: 1, output_neutral: 0},
      course: %{output_min: -0.5, output_max: 0.5, output_neutral: 0},
      speed: %{output_min: -2, output_max: 2, output_neutral: 0}
    }
  end
end
