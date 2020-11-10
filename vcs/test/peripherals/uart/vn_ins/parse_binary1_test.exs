defmodule Peripherals.VnIns.ParseBinary1Test do
  use ExUnit.Case

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link("T28")
    {:ok, []}
  end

  test "Read Binary1 messages" do
    config = Configuration.Module.Peripherals.Uart.get_vn_imu_config("all")
    {:ok, pid} = Peripherals.Uart.Estimation.VnIns.Operator.start_link(config)
    Process.sleep(3500000)
    assert true
  end
end
