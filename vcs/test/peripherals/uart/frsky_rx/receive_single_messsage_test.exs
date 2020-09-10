defmodule Peripherals.FrskyRx.ReceiveSingleMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Receive Single Message" do
    Logger.info("Receive Single Message test")
    Peripherals.Uart.FrskyRx.start_link(%{device_description: "Feather"})
    Process.sleep(500)
    Enum.each(0..10000, fn _index ->
      Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
      Process.sleep(20)
    end)
  end
end
