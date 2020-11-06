defmodule Peripherals.Uart.FrskyRx.ReadFrskyTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Receive Single Message" do
    Logger.info("Receive Single Message test")
    frsky_rx_config = Configuration.Module.Peripherals.Uart.get_frsky_rx_config()
    Peripherals.Uart.Command.Rx.Operator.start_link(frsky_rx_config)
    Process.sleep(50000)
    # Enum.each(0..10000, fn _index ->
    #   Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
    #   Process.sleep(20)
    # end)
  end

  test "Alternate UART" do
    Logger.info("Receive Single Message test")
    frsky_rx_config =   %{
      device_description: "ttyAMA0",
      baud: 100_000,
      stop_bits: 2,
      rx_framing_timeout: 7,
      rx_module: :Frsky
    }

    Peripherals.Uart.Command.Rx.Operator.start_link(frsky_rx_config)
    Process.sleep(50000)
    # Enum.each(0..10000, fn _index ->
    #   Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
    #   Process.sleep(20)
    # end)
  end

end
