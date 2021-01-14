defmodule Peripherals.VnIns.ParseBinary1Test do
  use ExUnit.Case

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    # MessageSorter.System.start_link("CessnaZ2m")
    {:ok, []}
  end

  test "Read Binary1 messages" do
    config = Configuration.Module.Peripherals.Uart.get_vn_imu_config("usb")

    {:ok, pid} = Peripherals.Uart.Estimation.VnIns.Operator.start_link(config)
    Process.sleep(3500000)
    assert true
  end
end
