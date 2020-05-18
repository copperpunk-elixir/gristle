defmodule Peripherals.IsIns.ParsePimuTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "Read PIMU messages" do
    {:ok, pid} = Peripherals.Uart.IsIns.start_link(%{})
    Process.sleep(4500)
    assert true
  end
end
