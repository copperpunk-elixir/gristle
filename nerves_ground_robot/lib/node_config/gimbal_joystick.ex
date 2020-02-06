defmodule NodeConfig.GimbalJoystick do
  def get_config() do
    # --- COMMS ---
    comms = %{
      node_name: :gimbal_joystick,
      nodes_to_connect: [],
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
      send_msg_switch_pin: 25,
      joystick_cmd_message: %{group: :gimbal_commands, topic: :attitude_cmd},
      joystick_cmd_sorting: %{priority: 1, authority: 1, time_validity_ms: 20},
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
