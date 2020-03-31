defmodule TestConfigs.Pids do
  def get_pid_config_roll_yaw() do
    pids = %{
      roll: %{aileron: %{kp: 1.0, weight: 0.9},
              rudder: %{kp: 0.1, weight: 0.2}
             },
      yaw: %{aileron: %{kp: 0.2, weight: 0.1},
             rudder: %{kp: 0.5, weight: 0.8}
      }
    }
    classification = [1,2]
    time_validity_ms = 200
    %{
      pids: pids,
      actuator_output_msg_classification: classification,
      actuator_output_msg_time_validity_ms: time_validity_ms
    }
  end
end
