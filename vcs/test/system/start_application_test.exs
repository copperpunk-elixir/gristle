defmodule System.StartApplicationTest do
  use ExUnit.Case

  test "Start Application" do
    Common.Application.start(nil,nil)
    Process.sleep(1000)
  end
end
