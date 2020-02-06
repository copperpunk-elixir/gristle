defmodule NodeConfig.TrackVehicleJoystick do
  def get_config() do
    # --- COMMS ---
    comms = %{
      node_name: :track_vehicle_joystick,
      nodes_to_connect: [],
      groups: [:track_vehicle_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- JOYSTICK ---
    # Joystick ADC
    x_axis = %{
      pin: 0,
      cmd: :turn,
      inverted: false,
      multiplier: 1.0,
    }

    y_axis = %{
      pin: 1,
      cmd: :speed,
      inverted: false,
      multiplier: 1.0
    }

    joystick_controller = %{
      send_msg_switch_pin: 25,
      joystick_cmd_message: %{group: :track_vehicle_commands, topic: :turn_and_speed_cmd},
      joystick_loop_interval_ms: 10,
      joystick_config: %{},
      channels: [x_axis, y_axis]
    }

    # --- RETURN ---
    %{
      comms: comms,
      joystick_controller: joystick_controller,
    }
  end
end
