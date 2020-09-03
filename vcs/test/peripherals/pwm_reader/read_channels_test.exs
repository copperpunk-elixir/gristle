defmodule Peripherals.PwmReader.ReadChannelsTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Read Pwm Channels Test" do
    Logger.info("Parse Message Test")
    delta_int_max = 1
    config = Configuration.Module.Peripherals.Uart.get_pwm_reader_config();
    {:ok, pid} = Peripherals.Uart.PwmReader.Operator.start_link(config)
    Process.sleep(100000)
  end
end
