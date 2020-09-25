defmodule Peripherals.InfiniteRetriesTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  # test "Open port" do
  #   Logger.info("Open Port test")
  #   config = Configuration.Module.Peripherals.Uart.get_dsm_rx_config()
  #   description = config.device_description
  #   baud = config.baud
  #   active = true
  #   {:ok, uart_ref} = Circuits.UART.start_link()
  #   options = [baud: baud, active: active]
  #   Peripherals.Uart.Utils.open_interface_connection_infinite(uart_ref, description, options)
  #   # Peripherals.Uart.Command.Dsm.Operator.start_link(%{device_description: "CP2104"})
  #   Process.sleep(50000)
  # end

  test "Start Operator" do
    Logger.info("Start Operator test")
    module = :Xbee
    {module_key, config} = Configuration.Module.Peripherals.Uart.get_module_key_and_config_for_module(module, :hil)
    op_module = Module.concat(Peripherals.Uart, module_key)
    |> Module.concat(Operator)
    apply(op_module, :start_link, [config])
    # Peripherals.Uart.Command.Dsm.Operator.start_link(config)
    Process.sleep(50000)
  end

end
