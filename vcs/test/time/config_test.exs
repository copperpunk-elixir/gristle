defmodule Time.ConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    Common.Utils.common_startup()
    RingLogger.attach()
    model_type = "T28"
    {:ok, [model_type: model_type]}
  end

  test "All test", context do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    model_type = context[:model_type]
    config = Configuration.Module.get_config(Time, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:server][:server_loop_interval_ms] == 10_000
    Process.sleep(200)
  end
end
