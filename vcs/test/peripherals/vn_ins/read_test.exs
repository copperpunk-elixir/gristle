defmodule Peripherals.VnIns.ReadTest do
  use ExUnit.Case

  test "Read from INS" do
    Peripherals.Uart.VnIns.start_link(%{})
    Process.sleep(3000)
  end
end
