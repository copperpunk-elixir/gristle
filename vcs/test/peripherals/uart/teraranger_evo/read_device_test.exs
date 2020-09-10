defmodule Peripherals.Uart.TerarangerEvo.ReadDeviceTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Read Device Test" do
    config = %{device_description: "STM32"}
    {:ok, pid} = Peripherals.Uart.TerarangerEvo.start_link(config)
    Process.sleep(10000)
  end
end
