defmodule NodeConfig.GimbalJoystick do
  def get_config() do
    # --- COMMS ---
    comms = %{
      groups: [:gimbal_commands],
      interface: NodeConfig.Master.get_interface(),
      cookie: NodeConfig.Master.get_cookie()
    }

    # --- JOYSTICK ---
    # Joystick ADC
    x_axis = %{
      pin: 0,
      cmd: :roll,
      inverted: false,
      multiplier: 0.524
    }

    y_axis = %{
      pin: 1,
      cmd: :pitch,
      inverted: true,
      multiplier: 0.524
    }

    joystick_controller = %{
      joystick_driver_config: %{driver: :adsadc},
      send_msg_switch_pin: 25,
      joystick_cmd_header: %{group: :gimbal_commands, topic: :attitude_cmd},
      joystick_cmd_classification: %{priority: 1, authority: 1, time_validity_ms: 1000},
      joystick_loop_interval_ms: 10,
      channels: %{roll: x_axis, pitch: y_axis}
    }

    # --- RETURN ---
    %{
      comms: comms,
      joystick_controller: joystick_controller,
    }
  end
end
