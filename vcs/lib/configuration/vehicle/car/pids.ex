defmodule Configuration.Vehicle.Car.Pids do
  @spec get_config() :: map()
  def get_config() do
    constraints = %{
      steering: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      throttle: %{output_min: 0, output_max: 1.0, output_neutral: 0},
      yawrate: %{output_min: -1.5, output_max: 1.5, output_neutral: 0},
      yaw: %{output_min: -0.2, output_max: 0.2, output_neutral: 0.0},
      thrust: %{output_min: -1, output_max: 1, output_neutral: 0}
    }

    pids = %{
      yawrate: %{steering: Map.merge(%{kp: 0.5}, constraints.steering)},
      thrust: %{throttle: Map.merge(%{kp: 1.0}, constraints.throttle)},
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
