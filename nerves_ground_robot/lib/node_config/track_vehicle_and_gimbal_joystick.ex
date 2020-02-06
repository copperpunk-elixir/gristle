defmodule NodeConfig.TrackVehicleAndGimbalJoystick do
  def get_config() do
    # --- COMMS ---
    comms = %{
      node_name: :track_vehicle_and_gimbal_joystick,
      nodes_to_connect: [],
      groups: [:gimbal_commands, :track_vehicle_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- GIMBAL JOYSTICK ---
    # Joystick ADC
    x_axis_gimbal = %{
      pin: 0,
      cmd: :roll,
      inverted: false,
      multiplier: 0.524
    }

    y_axis_gimbal = %{
      pin: 1,
      cmd: :pitch,
      inverted: true,
      multiplier: 0.524
    }

    joystick_controller_gimbal = %{
      name: :joystick_gimbal,
      send_msg_switch_pin: 25,
      joystick_cmd_message: %{group: :gimbal_commands, topic: :attitude_cmd},
      joystick_loop_interval_ms: 10,
      joystick_config: %{address: 0x48},
      channels: [x_axis_gimbal, y_axis_gimbal]
    }

    # --- TRACK VEHICLE JOYSTICK ---
    # Joystick ADC
    x_axis_track_vehicle = %{
      pin: 0,
      cmd: :turn,
      inverted: false,
      multiplier: 1.0,
    }

    y_axis_track_vehicle = %{
      pin: 1,
      cmd: :speed,
      inverted: false,
      multiplier: 1.0
    }

    joystick_controller_track_vehicle = %{
      name: :joystick_track_vehicle,
      send_msg_switch_pin: 25,
      joystick_cmd_message: %{group: :track_vehicle_commands, topic: :turn_and_speed_cmd},
      joystick_loop_interval_ms: 10,
      joystick_config: %{address: 0x49},
      channels: [x_axis_track_vehicle, y_axis_track_vehicle]
    }

    # --- RETURN ---
    %{
      comms: comms,
      joystick_controller: [joystick_controller_gimbal, joystick_controller_track_vehicle]
    }
  end
end
