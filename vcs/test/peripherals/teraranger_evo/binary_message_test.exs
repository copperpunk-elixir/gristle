defmodule Peripherals.Uart.TerarangerEvo.BinaryMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    {:ok, []}
  end

  test "Binary Message Test" do
    message = [0,0x11,1]
    exp_crc = 0x45
    crc = Peripherals.Uart.TerarangerEvo.calculate_checksum(message)
    assert crc == exp_crc

    message = [0,0x11,0x2]
    exp_crc = 0x4C
    crc = Peripherals.Uart.TerarangerEvo.calculate_checksum(message)
    assert crc == exp_crc

    range = 2000
    state = %{
      range: nil,
      start_byte_found: false,
              remaining_buffer: [],
              new_range_data_to_publish: false
             }
    message = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(range)
    state = Peripherals.Uart.TerarangerEvo.parse_data_buffer(message, state)
    assert state.range == range*0.001

  end
end
