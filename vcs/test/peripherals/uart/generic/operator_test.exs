defmodule Simulation.Ublox.SendImuMsgTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    {:ok, []}
  end

  test "connect generic peripheral test" do
    config = Configuration.Module.Peripherals.Uart.get_generic_config("usb")
    Peripherals.Uart.Generic.Operator.start_link(config)
    Process.sleep(100000)
  end
end
