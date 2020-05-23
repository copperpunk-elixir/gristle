defmodule TestConfigs.Pids do
  def get_pid_config_plane() do

    constraints = %{
      aileron: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      elevator: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      rudder: %{output_min: 0, output_max: 1.0, output_neutral: 0.5},
      throttle: %{output_min: 0, output_max: 1.0, output_neutral: 0},
      rollrate: %{output_min: -0.5, output_max: 0.5, output_neutral: 0},
      pitchrate: %{output_min: -0.4, output_max: 0.4, output_neutral: 0},
      yawrate: %{output_min: -1.5, output_max: 1.5, output_neutral: 0},
      roll: %{output_min: -0.2, output_max: 0.2, output_neutral: -0.02},
      pitch: %{output_min: -0.2, output_max: 0.2, output_neutral: 0},
      yaw: %{output_min: -0.2, output_max: 0.2, output_neutral: 0.01},
      thrust: %{output_min: -1, output_max: 1, output_neutral: 0}
    }

    pids = %{
      rollrate: %{aileron: Map.merge(%{kp: 0.8}, constraints.aileron)},
      pitchrate: %{elevator: Map.merge(%{kp: 0.9}, constraints.elevator)},
      yawrate: %{rudder: Map.merge(%{kp: 0.5}, constraints.rudder)},
      thrust: %{throttle: Map.merge(%{kp: 1.0}, constraints.throttle)},
      roll: %{rollrate: Map.merge(%{kp: 0.075}, constraints.rollrate)},
      pitch: %{pitchrate: Map.merge(%{kp: 0.2}, constraints.pitchrate)},
      yaw: %{yawrate: Map.merge(%{kp: 3.0}, constraints.yawrate)},
      course: %{roll: Map.merge(%{kp: 0.2}, constraints.roll),
                 yaw: Map.merge(%{kp: 0.1}, constraints.yaw)},
      speed: %{thrust: Map.merge(%{kp: 1.0, weight: 0.9}, constraints.thrust),
               pitch: Map.merge(%{kp: -0.2, weight: 0.1}, constraints.pitch)},
      altitude: %{thrust: Map.merge(%{kp: 0.05, weight: 0.1}, constraints.thrust),
                  pitch: Map.merge(%{kp: 1.0, weight: 0.9}, constraints.pitch)},
    }
    # rate_or_position = %{
    #     aileron: :rate,
    #     elevator: :rate,
    #     rudder: :rate,
    #     throttle: :position,
    #     rollrate: :rate,
    #     pitchrate: :rate,
    #     yawrate: :rate,
    #     thrust: :position,
    #     roll: :rate,
    #     pitch: :rate,
    #     yaw: :rate,
    #     speed: :rate
    # }

    classification = [1,2]
    time_validity_ms = 200
    %{
      pids: pids,
      # rate_or_position: rate_or_position,
      actuator_cmds_msg_classification: classification,
      actuator_cmds_msg_time_validity_ms: time_validity_ms,
      pv_cmds_msg_classification: classification,
      pv_cmds_msg_time_validity_ms: time_validity_ms
    }
  end
end
