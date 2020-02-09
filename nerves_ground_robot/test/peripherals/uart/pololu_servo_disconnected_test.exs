defmodule Peripherals.Uart.PololuServo.DisconnectedTest do
  use ExUnit.Case
  doctest Peripherals.Uart.PololuServo

  test "PololuServo - not connected" do
    assert Peripherals.Uart.PololuServo.get_message_for_channel_and_output_ms(0, 1500) == [0x84, 0, 112, 46, 43]
    assert Peripherals.Uart.PololuServo.get_message_for_channel_and_output_ms(1, 1100) == [0x84, 1, 48, 34, 36]
    assert Peripherals.Uart.PololuServo.output_to_ms(0.25, false, 1100, 1900) == 1300
    assert Peripherals.Uart.PololuServo.output_to_ms(0.25, true, 1100, 1900) == 1700
    assert Peripherals.Uart.PololuServo.output_to_ms(1.5, true, 1100, 1900) == nil
    assert Peripherals.Uart.PololuServo.get_checksum_for_packet([0x83, 0x01]) == 23
  end
end
