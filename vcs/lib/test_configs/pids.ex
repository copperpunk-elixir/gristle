defmodule TestConfigs.Pids do
  def get_pid_config_roll_yaw() do
    pids = %{
      roll: %{aileron: %{kp: 1.0, weight: 0.3},
              rudder: %{kp: 0.1, weight: 0.2}
             },
      yaw: %{aileron: %{kp: 0.2, weight: 0.6},
             rudder: %{kp: 0.5, weight: 0.8}
      },
      vx: %{throttle: %{kp: 0.5, weight: 1.0}}
    }
    rate_or_position = %{
        aileron: :rate,
        rudder: :rate,
        throttle: :position
    }

    one_or_two_sided = %{
      aileron: :two_sided,
      rudder: :two_sided,
      throttle: :one_sided
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
