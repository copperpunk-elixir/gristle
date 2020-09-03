defmodule Simulation.PwmInputTest do
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
    Peripherals.Uart.PwmReader.Operator.start_link(config)
    xplane_config = Configuration.Module.Simulation.get_simulation_xplane_send_config(:Plane)
    Simulation.XplaneSend.start_link(xplane_config)
    Process.sleep(100000)

  end
end
