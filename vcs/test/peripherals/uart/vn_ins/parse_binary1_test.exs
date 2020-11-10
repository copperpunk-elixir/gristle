defmodule Peripherals.VnIns.ParseBinary1Test do
  use ExUnit.Case

  setup do
    RingLogger.attach()
    Common.Utils.common_startup()
    MessageSorter.System.start_link("T28")
    {:ok, []}
  end

  test "Read Binary1 messages" do
    config = Configuration.Module.Peripherals.Uart.get_vn_imu_config("ttyAMA3")
    {:ok, pid} = Peripherals.Uart.Estimation.VnIns.Operator.start_link(config)
    Process.sleep(3500000)
    Peripherals.Uart.Estimation.VnIns.close()
    Process.sleep(1000)
    assert true
  end
end
