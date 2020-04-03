defmodule Joystick.Controller.DisconnectedTest do
  require Logger
  use ExUnit.Case
  doctest Joystick.Controller

  config = NodeConfig.GimbalJoystick.get_config()
  config = put_in(config, [:joystick_controller, :joystick_driver_config, :driver], nil)
  config = put_in(config, [:joystick_controller, :send_msg_switch_pin], nil)

  Common.Utils.Comms.start_registry(:topic_registry)
  Common.ProcessRegistry.start_link

  Joystick.Controller.start_link(config.joystick_controller)


  roll_channel = config.joystick_controller.channels.roll
  roll_output_desired = 2.0
  output_all_channels = Joystick.Controller.set_output_for_channel_and_value(roll_channel, roll_output_desired)
  assert Map.get(output_all_channels, :roll) == Joystick.Controller.calculate_output_for_channel_and_value(roll_channel, roll_output_desired)
end
