defmodule NodeConfig.Gimbal do
  alias NodeConfig.Utils.PidActuatorInterface
  def get_config() do
    # --- COMMS ---
    comms = %{
      #TODO: there should be only one node that is ever called master, and it shouldn't do anything else
      # except exist
      node_name: :gimbal,
      groups: [:gimbal_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- SYSTEM ---
    gimbal_controller = %{
      pid_actuator_links: [
        %{process_variable: :roll, actuator: :roll_axis_motor, failsalfe_value: 0},
        %{process_variable: :pitch, actuator: :pitch_axis_motor, failsafe_value: 0}
      ],
        # roll_to_roll_axis_motor: %{process_variable: :roll, actuator: :roll_axis_motor, output: 0},
      #   pitch_to_pitch_axis_motor: %{process_variable: :pitch, actuator: :pitch_axis_motor, output: 0}
      # },
      subscriber_topics: [:euler_eulerrate_dt, :imu_status, :actuator_status, :attitude_cmd],
      classification: %{priority: 0, authority: 0, time_validity_ms: 1000},
      command_priority_max: 3
    }

    # --- IMU ---
    imu = %{
      publisher_topics: [:imu_status, :euler_eulerrate_dt],
      interface: %{name: :uart, reset_pin: 24, wake_pin: 25, update_interval_ms: 10}
    }

    # --- PID CONTROLLER ---
    pids =
      PidActuatorInterface.new_pid_config()
      |> PidActuatorInterface.add_pid(:roll, :roll_axis_motor, 20.0, 0, 0.005, :position, :two_sided)
      |> PidActuatorInterface.add_pid(:pitch, :pitch_axis_motor, 20.0, 0, 0.005, :position, :two_sided)

    pid_controller = %{
      pids: pids
    }
      # pids: %{
     #    roll: %{
    #       roll_axis_motor: %{
    #         kp: 20.0,
    #         ki: 0,
    #         kd: 0.005,
    #         rate_or_position: :position,
    #         one_or_two_sided: :two_sided
    #       }
    #     },
    #     pitch: %{
    #       pitch_axis_motor: %{
    #         kp: 20.0,
    #         ki: 0,
    #         kd: 0.005,
    #         rate_or_position: :position,
    #         one_or_two_sided: :two_sided
    #       }
    #     }
    #   }
    # }

    # --- ACTUATOR CONTROLLER ---
    actuators =
      PidActuatorInterface.new_actuators_config()
      |> PidActuatorInterface.add_actuator(:roll_axis_motor, 0, false, 1100, 1900)
      |> PidActuatorInterface.add_actuator(:pitch_axis_motor, 1, false, 1100, 1900)

    actuator_controller = %{
      # local_publisher_topics: [:actuator_status],
      pwm_freq: 100,
      actuator_driver: :pololu,
      actuators: actuators,
      command_priority_max: 3
      # %{
      #   roll_axis_motor: %{
      #     channel_number: 0,
      #     reversed: false,
      #     min_pw_ms: 1100,
      #     max_pw_ms: 1900
      #   },
      #   pitch_axis_motor: %{
      #     channel_number: 1,
      #     reversed: false,
      #     min_pw_ms: 1100,
      #     max_pw_ms: 1900
      #   }
      # }
    }

    # --- RETURN ---
    %{
      comms: comms,
      gimbal_controller: gimbal_controller,
      imu: imu,
      pid_controller: pid_controller,
      actuator_controller: actuator_controller,
    }
  end
end
