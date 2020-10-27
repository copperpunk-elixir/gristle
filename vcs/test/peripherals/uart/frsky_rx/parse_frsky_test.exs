defmodule Peripherals.Uart.FrskyRx.ParseFrskyTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Parse Single Message" do
    Logger.info("Parse Single Message test")
    rx_module = Peripherals.Uart.Command.Rx.Frsky
    good_a = [15,220,3,95,68,193,199,138,137,131,111,226,224,3,31,248,192,7,62,240,129,15,124,0,0]
    good_b = [24,0,0,15,221,3,95,68,193,199,138,137,131,111,226,224,3,31,248,192,7,62,240,129,15,124,0,0]
    rx = Peripherals.Uart.Command.Rx.Frsky.new()
    assert rx.payload_ready == false
    # rx = Peripherals.Uart.Command.Rx.Operator.parse(rx_module, rx, good_a)
    # assert rx.payload_ready == true
    rx = Peripherals.Uart.Command.Rx.Operator.parse(rx_module, rx, good_b)
    Process.sleep(100)
    assert rx.payload_ready == true
    Logger.info("channels: #{inspect(Peripherals.Uart.Command.Rx.Frsky.get_channels(rx))}")
    Process.sleep(100)
    # Enum.each(0..10000, fn _index ->
    #   Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
    #   Process.sleep(20)
    # end)
  end
end
