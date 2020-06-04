defmodule Configuration.Vehicle.Plane.Pids do
  @spec get_config() :: map()
  def get_config() do
    constraints = get_constraints()

    pids = %{
      rollrate: %{aileron: Map.merge(%{kp: 1.0}, constraints.aileron)},
      pitchrate: %{elevator: Map.merge(%{kp: 1.0}, constraints.elevator)},
      yawrate: %{rudder: Map.merge(%{kp: 1.0}, constraints.rudder)},
      thrust: %{throttle: Map.merge(%{kp: 1.0}, constraints.throttle)},
      roll: %{rollrate: Map.merge(%{kp: 0.1}, constraints.rollrate)},
      pitch: %{pitchrate: Map.merge(%{kp: 0.1}, constraints.pitchrate)},
      yaw: %{yawrate: Map.merge(%{kp: 0.1}, constraints.yawrate)},
      course: %{roll: Map.merge(%{kp: 1.0}, constraints.roll),
                yaw: Map.merge(%{kp: 0.1}, constraints.yaw)},
      speed: %{thrust: Map.merge(%{kp: 1.0, weight: 1.0}, constraints.thrust),
               pitch: Map.merge(%{kp: -0.2, weight: 0.0}, constraints.pitch)},
      altitude: %{thrust: Map.merge(%{kp: 0.05, weight: 0.0}, constraints.thrust),
                  pitch: Map.merge(%{kp: 1.0, weight: 1.0}, constraints.pitch)},
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
      aileron: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      elevator: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      rudder: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      throttle: %{output_min: 0, output_max: 1.0, output_neutral: 0},
      rollrate: %{output_min: -0.5, output_max: 0.5, output_neutral: 0},
      pitchrate: %{output_min: -0.4, output_max: 0.4, output_neutral: 0},
      yawrate: %{output_min: -1.5, output_max: 1.5, output_neutral: 0},
      roll: %{output_min: -0.2, output_max: 0.2, output_neutral: 0.0},
      pitch: %{output_min: -0.2, output_max: 0.2, output_neutral: 0},
      yaw: %{output_min: -0.2, output_max: 0.2, output_neutral: 0.0},
      thrust: %{output_min: 0, output_max: 1, output_neutral: 0},
      course: %{output_min: -0.5, output_max: 0.5, output_neutral: 0},
      speed: %{output_min: -2, output_max: 2, output_neutral: 0},
      altitude: %{output_min: -5, output_max: 5, output_neutral: 0},
    }
  end
end
