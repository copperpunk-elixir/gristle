defmodule Watchdog.ConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    Common.Utils.common_startup()
    RingLogger.attach()
    {:ok,[]}
  end

  test "All test" do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    name = :roofus
    interval = 100
    local_config = Configuration.Module.Watchdog.get_local(name, interval)
    global_config = Configuration.Module.Watchdog.get_global(name, interval)
    Logger.debug("local config: #{inspect(local_config)}")
    Logger.debug("global config: #{inspect(global_config)}")
    assert local_config[:name] == name
    assert global_config[:expected_interval_ms] == interval
    assert local_config[:local_or_global] == :local
    assert global_config[:local_or_global] == :global

    Process.sleep(200)
  end
end
