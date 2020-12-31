defmodule Peripherals.Uart.Generic.PvatPubSubTest do
  use ExUnit.Case
  require Logger

  @generic_module Peripherals.Uart.Generic.Operator

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    {:ok, []}
  end

  test "connect generic peripheral test" do
    config = Configuration.Module.Peripherals.Uart.get_generic_config("usb")
    uart_port = config[:uart_port]
    name = Peripherals.Uart.Generic.Operator.via_tuple(uart_port)
    Peripherals.Uart.Generic.Operator.start_link(config)
    Process.sleep(100)
    # Peripherals.Uart.Generic.construct_and_send_message(:generic_sub, [0x00, 50], name)
    Process.sleep(5000)
    attitude = %{roll: 0.1, pitch: 0.2, yaw: 0.3}
    bodyrate = %{rollrate: -0.1, pitchrate: -0.2, yawrate: -0.3}
    position = %{latitude: 0.5, longitude: -1.0, altitude: 123.4, agl: 100.0}
    velocity = %{speed: 10.0, course: 0.123, vertical: -1.23, airspeed: 9.9}
    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {{:pv_values, :attitude_bodyrate}, attitude, bodyrate, 0.025},
      self())
    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {{:pv_values, :position_velocity}, position, velocity, 0.025},
      self())

    Process.sleep(100)
    # Subscribe to pvat
    Process.sleep(100000)
  end
end
