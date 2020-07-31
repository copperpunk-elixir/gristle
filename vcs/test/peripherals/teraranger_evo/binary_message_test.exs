defmodule Peripherals.Uart.TerarangerEvo.BinaryMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
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

    Enum.reduce(0..255, state, fn (x,state) ->
      m1 = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(1000+x)
      m2 = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(2000+2*x)
      m3 = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(3000 + 3*x)
      buffer = m1 ++ [x] ++ m2 ++ [x] ++ m3
      state = Peripherals.Uart.TerarangerEvo.parse_data_buffer(buffer,state)
      assert state.range == (3000+3*x)*0.001
      state
    end)
  end

  test "Send Range to Evo" do
    config = %{device_description: nil}
    {:ok, pid} = Peripherals.Uart.TerarangerEvo.start_link(config)
    Process.sleep(100)
    exp_range = 12.345
    message = Peripherals.Uart.TerarangerEvo.create_message_for_range_m(exp_range)
    send(pid,{:circuits_uart, 0,:binary.list_to_bin(message)})
    Process.sleep(100)
    range = Peripherals.Uart.TerarangerEvo.get_range()
    assert range == exp_range
    Enum.each(0..255, fn x ->
      m1 = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(1000+x)
      m2 = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(2000+2*x)
      m3 = Peripherals.Uart.TerarangerEvo.create_message_for_range_mm(3000 + 3*x)
      buffer = m1 ++ [x] ++ m2 ++ [x] ++ m3
      send(pid,{:circuits_uart, 0,:binary.list_to_bin(buffer)})
      Process.sleep(20)
      range = Peripherals.Uart.TerarangerEvo.get_range()
      assert range == (3000+3*x)*0.001
    end)

  end
end
