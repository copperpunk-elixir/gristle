defmodule Watchdog.CreateWatchdogTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    RingLogger.attach()
    Process.sleep(100)
    {:ok, []}
  end

  test "Create watchdog Test" do
    name = :test
    config = Configuration.Module.Watchdog.get_local(name, 40)
    Watchdog.Active.start_link(config)
    Process.sleep(1000)
    assert Watchdog.Active.is_fed?(name) == false
    Enum.each(1..5, fn _i ->
      Watchdog.Active.feed(name)
    end)
    Process.sleep(220)
    assert Watchdog.Active.is_fed?(name) == true
    Process.sleep(200)
    assert Watchdog.Active.is_fed?(name) == false
  end
end
