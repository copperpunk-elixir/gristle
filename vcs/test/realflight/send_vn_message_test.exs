defmodule Realflight.SendVnMessageTest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach()
    Comms.System.start_link()
    config = [host_ip: "192.168.7.136", sim_loop_interval_ms: 20]
    Simulation.Realflight.start_link(config)
    Peripherals.Uart.Estimation.VnIns.Operator.start_link(Configuration.Module.Peripherals.Uart.get_vn_ins_config("usb"))
    Peripherals.Uart.Estimation.TerarangerEvo.Operator.start_link(Configuration.Module.Peripherals.Uart.get_teraranger_evo_config("usb"))
    Estimation.System.start_link(Configuration.Module.Estimation.get_config(nil,nil))
    {:ok, []}
  end

  test "Send Vn Message Test", context do
    Process.sleep(1000000)
  end
end
