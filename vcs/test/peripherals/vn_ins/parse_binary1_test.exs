defmodule Peripherals.Uart.VnIns.ParseBinary1Test do
  use ExUnit.Case

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    {:ok, []}
  end

  test "Read Binary1 messages" do
    config = Configuration.Module.Peripherals.Uart.get_vn_ins_config(:all)
    {:ok, pid} = Peripherals.Uart.Estimation.VnIns.start_link(config)
    Process.sleep(3500000)
    Peripherals.Uart.VnIns.close()
    Process.sleep(1000)
    assert true
  end
end
