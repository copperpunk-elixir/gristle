defmodule System.StartApplicationTest do
  use ExUnit.Case

  test "Start Application" do
    Common.Application.start(nil,nil)
    Process.sleep(100000)
  end
end
