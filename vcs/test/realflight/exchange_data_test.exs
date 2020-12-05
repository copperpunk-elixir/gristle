defmodule Realflight.ExchangeDataTest do
  use ExUnit.Case
  require Logger

  @default_latitude 41.769201
  @default_longitude -122.506394

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    {:ok, []}
  end

  test "exchange data test" do
    config = [host_ip: "192.168.7.136", sim_loop_interval_ms: 20]
    Simulation.Realflight.start_link(config)
    Process.sleep(100000)

  end
end
