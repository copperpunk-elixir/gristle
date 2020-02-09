defmodule Peripherals.Uart.PololuServo.ConnectedTest do
  alias Peripherals.Uart.PololuServo
  use ExUnit.Case
  doctest Peripherals.Uart.PololuServo

  test "PololuServo - Connected" do
    # Open port
    uart_ref = PololuServo.open_port()
    assert uart_ref != nil
    # Set output for channel
    channel = 1
    output = 1200
    PololuServo.write_microseconds(uart_ref, channel, output)
    assert PololuServo.get_output_for_channel_number(uart_ref, channel) == output
    # Repeat for new output
    output = 1623
    PololuServo.write_microseconds(uart_ref, channel, output)
    assert PololuServo.get_output_for_channel_number(uart_ref, channel) == output

  end
end
