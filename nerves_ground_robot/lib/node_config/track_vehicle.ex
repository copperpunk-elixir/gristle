defmodule NodeConfig.TrackVehicle do
  def get_config() do
    # --- COMMS ---
    comms = %{
      #TODO: there should be only one node that is ever called master, and it shouldn't do anything else
      # except exist
      groups: [:track_vehicle_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- SYSTEM ---
    track_vehicle_controller = %{
      actuator_loop_interval_ms: 10,
      speed_to_turn_ratio: 3.0,
      subscriber_topics: [:actuator_status, :speed_and_turn_cmd],
      classification: %{priority: 0, authority: 0, time_validity_ms: 1000},
      command_priority_max: 3
    }

    # --- ACTUATOR CONTROLLER ---
    left_track_actuator = %{
      channel_number: 0,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900
    }
    right_track_actuator = %{
      channel_number: 1,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900
    }

    actuators =
      PidActuatorInterface.new_actuators_config()
      |> PidActuatorInterface.add_actuator(:left_track_motor, 0, false, 1100, 1900, 1500)
      |> PidActuatorInterface.add_actuator(:right_track_motor, 1, false, 1100, 1900, 1500)
    actuator_controller = %{
      # local_publisher_topics: [:actuator_status],
      pwm_freq: 100,
      actuators: actuators
    }

    # --- RETURN ---
    %{
      comms: comms,
      track_vehicle_controller: track_vehicle_controller,
      actuator_controller: actuator_controller,
    }
  end
end
