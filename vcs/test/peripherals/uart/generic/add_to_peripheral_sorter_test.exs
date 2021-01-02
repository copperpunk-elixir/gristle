defmodule Peripherals.Uart.Generic.AddToPeripheralSorterTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)

    model_type = "CessnaZ2m"
    node_type = "all"
    nav_config = Configuration.Module.Navigation.get_config(model_type, node_type)
    sorter_config = Configuration.Module.MessageSorter.get_config(model_type, node_type)
    Enum.each(sorter_config, fn config ->
      Logger.debug("#{inspect(config)}")
      end
    )
    MessageSorter.System.start_link(sorter_config)
    Process.sleep(200)
    Navigation.System.start_link(nav_config)

    {:ok, []}
  end

  test "connect generic peripheral test" do
    config = Configuration.Module.Peripherals.Uart.get_generic_config("usb", "a")
    uart_port = config[:uart_port]
    name = Peripherals.Uart.Generic.Operator.via_tuple(uart_port)
    Peripherals.Uart.Generic.Operator.start_link(config)
    Process.sleep(100)
    Peripherals.Uart.Generic.construct_and_send_message(:orbit_inline, [0, 100.0, 0], name)
    Process.sleep(1000)
    Peripherals.Uart.Generic.construct_and_send_message(:orbit_inline, [1, 100.0, 0], name)
    # Process.sleep(100)
    # Subscribe to pvat
    Process.sleep(100000)
  end
end
