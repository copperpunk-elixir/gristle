defmodule NodeConfig.TrackVehicle do
  alias NodeConfig.Utils.PidActuatorInterface
  def get_config() do
    # --- COMMS ---
    comms = %{
      groups: [:track_vehicle_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- SYSTEM ---
    speed_pid_actuator_link = %{
      process_variable: :speed,
      actuator: nil,
      cmd_limit_min: -1,
      cmd_limit_max: 1,
      failsafe_cmd: 0,
    }

    turn_pid_actuator_link = %{
      process_variable: :turn,
      actuator: nil,
      cmd_limit_min: -1,
      cmd_limit_max: 1,
      failsafe_cmd: 0,
    }

    pid_actuator_links =
      PidActuatorInterface.new_pid_actuator_config()
      |> PidActuatorInterface.add_pid_actuator_link(speed_pid_actuator_link)
      |> PidActuatorInterface.add_pid_actuator_link(turn_pid_actuator_link)

    track_vehicle_controller = %{
      pid_actuator_links: pid_actuator_links,
      subscriber_topics: [:actuator_status, :speed_and_turn_cmd],
      actuator_cmd_classification: %{priority: 0, authority: 0, time_validity_ms: 1000}
    }

    # --- ACTUATOR INTERFACE_OUTPUT ---
    left_track_motor = %{
      name: :left_track_motor,
      channel_number: 0,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: 0.5
    }
    right_track_motor = %{
      name: :right_track_motor,
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
      |> PidActuatorInterface.add_actuator(left_track_motor)
      |> PidActuatorInterface.add_actuator(right_track_motor)
    actuator_interface_output = %{
      # local_publisher_topics: [:actuator_status],
      pwm_freq: 100,
      actuators: actuators
    }

    # --- RETURN ---
    %{
      comms: comms,
      track_vehicle_controller: track_vehicle_controller,
      actuator_interface_output: actuator_interface_output,
    }
  end
end
