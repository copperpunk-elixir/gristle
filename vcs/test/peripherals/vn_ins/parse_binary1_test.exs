defmodule Peripherals.VnIns.ParseBinary1Test do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    {:ok, []}
  end

  test "Read Binary1 messages" do
    {:ok, pid} = Peripherals.Uart.VnIns.start_link(%{})
    Process.sleep(3500)
    assert true
  end
end
