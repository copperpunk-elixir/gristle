defmodule TestConfigs.Pids do
  def get_pid_config_a() do
    pids = %{
      rollrate: %{aileron: %{kp: 0.8, weight: 1.0}},
      pitchrate: %{elevator: %{kp: 0.9, weight: 1.0}},
      yawrate: %{rudder: %{kp: 0.5, weight: 1.0}},
      thrust: %{throttle: %{kp: 0.1, weight: 1.0}},
      roll: %{rollrate: %{kp: 0.05, weight: 1.0, output_min: -0.5, output_max: 0.5, output_neutral: 0}},
      pitch: %{pitchrate: %{kp: 0.2, weight: 1.0, output_min: -0.4, output_max: 0.4, output_neutral: 0}},
      yaw: %{yawrate: %{kp: 3.0, weight: 1.0, output_min: -1.5, output_max: 1.5, output_neutral: 0}},
      heading: %{roll: %{kp: 0.1, weight: 0.1},
                 yaw: %{kp: 1.0, weight: 0.9}},
      speed: %{thrust: %{kp: 1.0, weight: 0.9},
               pitch: %{kp: -0.2, weight: 0.1}},
      height: %{thrust: %{kp: 0.05, weight: 0.1},
                pitch: %{kp: 1.0, weight: 0.9}},
    }
    rate_or_position = %{
        aileron: :rate,
        elevator: :rate,
        rudder: :rate,
        throttle: :position,
        rollrate: :rate,
        pitchrate: :rate,
        yawrate: :rate,
        thrust: :position,
        roll: :rate,
        pitch: :rate,
        yaw: :rate,
        speed: :rate
    }

    one_or_two_sided = %{
      aileron: :two_sided,
      elevator: :one_sided,
      rudder: :two_sided,
      throttle: :one_sided,
      rollrate: :two_sided,
      pitchrate: :two_sided,
      yawrate: :two_sided,
      thrust: :one_sided,
      roll: :two_sided,
      pitch: :two_sided,
      yaw: :two_sided,
      speed: :two_sided
    }
    classification = [1,2]
    time_validity_ms = 200
    %{
      pids: pids,
      rate_or_position: rate_or_position,
      one_or_two_sided: one_or_two_sided,
      actuator_output_msg_classification: classification,
      actuator_output_msg_time_validity_ms: time_validity_ms
    }
  end
end
