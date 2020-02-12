defmodule NodeConfig.Gimbal do
  alias NodeConfig.Utils.PidActuatorInterface
  def get_config() do
    # --- COMMS ---
    comms = %{
      #TODO: there should be only one node that is ever called master, and it shouldn't do anything else
      # except exist
      groups: [:gimbal_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- SYSTEM ---
    roll_pid_actuator_link = %{
      process_variable: :roll,
      actuator: :roll_axis_motor,
      cmd_limit_min: Common.Utils.Math.deg2rad(30),
      cmd_limit_max: Common.Utils.Math.deg2rad(-30),
      failsafe_cmd: 0
    }

    pitch_pid_actuator_link = %{
      process_variable: :pitch,
      actuator: :pitch_axis_motor,
      cmd_limit_min: Common.Utils.Math.deg2rad(30),
      cmd_limit_max: Common.Utils.Math.deg2rad(-30),
      failsafe_cmd: 0
    }
    pid_actuator_links =
      PidActuatorInterface.new_pid_actuator_config()
      |> PidActuatorInterface.add_pid_actuator_link(roll_pid_actuator_link)
      |> PidActuatorInterface.add_pid_actuator_link(pitch_pid_actuator_link)

    gimbal_controller = %{
      pid_actuator_links: pid_actuator_links,
      subscriber_topics: [:euler_eulerrate_dt, :imu_status, :actuator_status, :attitude_cmd],
      actuator_cmd_classification: %{priority: 0, authority: 0, time_validity_ms: 1000}
    }

    # --- IMU ---
    imu = %{
      publisher_topics: [:imu_status, :euler_eulerrate_dt],
      interface: %{name: :uart, reset_pin: 24, wake_pin: 25, update_interval_ms: 10}
    }

    # --- PID CONTROLLER ---
    roll_to_roll_axis_motor_pid = %{
      process_variable: :roll,
      actuator: :roll_axis_motor,
      kp: 20,
      ki: 0,
      kd: 0.005,
      rate_or_position: :position,
      one_or_two_sided: :two_sided
    }

    pitch_to_pitch_axis_motor_pid = %{
      process_variable: :pitch,
      actuator: :pitch_axis_motor,
      kp: 20,
      ki: 0,
      kd: 0.005,
      rate_or_position: :position,
      one_or_two_sided: :two_sided
    }
    pids =
      PidActuatorInterface.new_pid_config()
      |> PidActuatorInterface.add_pid(roll_to_roll_axis_motor_pid)
      |> PidActuatorInterface.add_pid(pitch_to_pitch_axis_motor_pid)

    pid_controller = %{
      pids: pids
    }

    # --- ACTUATOR CONTROLLER ---
    roll_axis_motor = %{
      name: :roll_axis_motor,
      channel_number: 0,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: 0.5
    }

    pitch_axis_motor = %{
      name: :pitch_axis_motor,
      channel_number: 1,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: 0.5
    }

    actuators =
      PidActuatorInterface.new_actuators_config()
      |> PidActuatorInterface.add_actuator(roll_axis_motor)
      |> PidActuatorInterface.add_actuator(pitch_axis_motor)

    actuator_controller = %{
      actuator_loop_interval_ms: 10,
      actuator_driver: :pololu,
      actuators: actuators
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
