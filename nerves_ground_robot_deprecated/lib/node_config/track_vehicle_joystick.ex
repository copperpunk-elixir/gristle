defmodule NodeConfig.TrackVehicleJoystick do
  def get_config() do
    # --- COMMS ---
    comms = %{
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

    joystick_interface_input = %{
      joystick_driver_config: %{driver: :adsadc},
      send_msg_switch_pin: 25,
      joystick_cmd_header: %{group: :track_vehicle_commands, topic: :speed_and_turn_cmd},
      joystick_cmd_classification: %{priority: 1, authority: 1, time_validity_ms: 100},
      joystick_loop_interval_ms: 50,
      channels: [x_axis, y_axis]
    }

    # --- RETURN ---
    %{
      comms: comms,
      joystick_interface_input: joystick_interface_input,
    }
  end
end
