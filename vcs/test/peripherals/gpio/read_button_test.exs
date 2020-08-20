defmodule Peripherals.Gpio.ReadButtonTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Read Button" do
    config = Configuration.Module.Peripherals.Gpio.get_config(nil, nil)
    Logger.info("clonfig: #{inspect(config)}")
    Peripherals.Gpio.Logging.Operator.start_link(Map.get(config, Logging))
    Process.sleep(10000)
  end
end
