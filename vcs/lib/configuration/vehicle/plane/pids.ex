defmodule Configuration.Vehicle.Plane.Pids do
  @spec get_config() :: map()
  def get_config() do
    constraints = get_constraints()

    pids = %{
      rollrate: %{aileron: Map.merge(%{kp: 0.5, ki: 0.0, kd: 0.005}, constraints.aileron)},
      pitchrate: %{elevator: Map.merge(%{kp: 0.25, ki: 0.0, kd: 0.00}, constraints.elevator)},
      yawrate: %{rudder: Map.merge(%{kp: 0.35, ki: 0.0, kd: 0.0025}, constraints.rudder)},
      thrust: %{throttle: Map.merge(%{kp: 1.0}, constraints.throttle)},
      roll: %{rollrate: Map.merge(%{kp: 5.0, kd: 0.025}, constraints.rollrate)},
      pitch: %{pitchrate: Map.merge(%{kp: 5.0, kd: 0.025}, constraints.pitchrate)},
      yaw: %{yawrate: Map.merge(%{kp: 5.0, kd: 0.000}, constraints.yawrate)},
      course: %{roll: Map.merge(%{kp: 2.0, ki: 0.01, kd: 0.2}, constraints.roll),
                yaw: Map.merge(%{kp: 0.1}, constraints.yaw)},
      speed: %{thrust: Map.merge(%{kp: 0.15, ki: 0.01, weight: 1.0}, constraints.thrust)},
      altitude: %{pitch: Map.merge(%{kp: 0.015, ki: 0.0, kd: 0*0.0155, weight: 1.0}, constraints.pitch)}
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
      rollrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      pitchrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      yawrate: %{output_min: -1.57, output_max: 1.57, output_neutral: 0},
      roll: %{output_min: -0.52, output_max: 0.52, output_neutral: 0.0},
      pitch: %{output_min: -0.52, output_max: 0.52, output_neutral: 0},
      yaw: %{output_min: -0.52, output_max: 0.52, output_neutral: 0.0},
      thrust: %{output_min: -1, output_max: 1, output_neutral: 0.0},
      course: %{output_min: -0.52, output_max: 0.52, output_neutral: 0},
      speed: %{output_min: -100, output_max: 100, output_neutral: 0},
      altitude: %{output_min: -10, output_max: 10, output_neutral: 0},
    }
  end
end
