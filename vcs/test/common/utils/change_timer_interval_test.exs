defmodule Common.Utils.ChangeTimerIntervalTest do
  use ExUnit.Case
  require Logger


  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    {:ok, []}
  end

  test "Change Timer Interval Test" do
    config = [name: :dummy]
    {:ok, pid} = Workshop.DummyGenserver.start_link(config)
    Process.sleep(100)
    timer = Common.Utils.start_loop(pid, 500, :timer)
    Process.sleep(3000)
    Common.Utils.stop_loop(timer)
    timer = Common.Utils.start_loop(pid, 2000, :timer)
    Process.sleep(10000)
  end
end
