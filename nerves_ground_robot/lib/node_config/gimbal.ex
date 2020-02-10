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
    pid_actuator_links =
      PidActuatorInterface.new_pid_actuator_config()
      |> PidActuatorInterface.add_pid_actuator_link(:roll, :roll_axis_motor, 0)
      |> PidActuatorInterface.add_pid_actuator_link(:pitch, :pitch_axis_motor, 0)

    gimbal_controller = %{
      pid_actuator_links: pid_actuator_links,
      subscriber_topics: [:euler_eulerrate_dt, :imu_status, :actuator_status, :attitude_cmd],
      actuator_cmd_classification: %{priority: 0, authority: 0, time_validity_ms: 1000},
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

    # --- ACTUATOR CONTROLLER ---
    actuators =
      PidActuatorInterface.new_actuators_config()
      |> PidActuatorInterface.add_actuator(:roll_axis_motor, 0, false, 1100, 1900)
      |> PidActuatorInterface.add_actuator(:pitch_axis_motor, 1, false, 1100, 1900)

    actuator_controller = %{
      actuator_loop_interval_ms: 10,
      actuator_driver: :pololu,
      actuators: actuators,
      command_priority_max: 3
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
