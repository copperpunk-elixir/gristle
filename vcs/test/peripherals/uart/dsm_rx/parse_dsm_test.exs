defmodule Peripherals.DsmRx.ParseDsmTest do
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
    good_a = [0, 0, 1, 240, 5, 240, 8, 86, 13, 240, 19, 137, 23, 137, 24, 86]
    good_b = [0, 0, 159, 137, 35, 137, 37, 240, 41, 240, 45, 240, 50, 0, 54, 0]
    dsm = Peripherals.Uart.Command.Dsm.new()
    assert dsm.payload_ready == false
    dsm = Peripherals.Uart.Command.Dsm.Operator.parse(dsm, good_a)
    channel_count = dsm.channel_count
    assert channel_count == 7
    assert dsm.payload_ready == false
    dsm = Peripherals.Uart.Command.Dsm.Operator.parse(dsm, good_b)
    channel_count = dsm.channel_count
    Process.sleep(100)
    assert channel_count == 14
    assert dsm.payload_ready == true
    Logger.info("channels: #{inspect(Peripherals.Uart.Command.Dsm.get_channels(dsm))}")
    Process.sleep(100)
    # Enum.each(0..10000, fn _index ->
    #   Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
    #   Process.sleep(20)
    # end)
  end
end
