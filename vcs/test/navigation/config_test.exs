defmodule Navigation.ConfigTest do
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
    config = Configuration.Module.get_config(Navigation, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:path_manager][:path_follower][:k_path] == 0.05
    assert config[:path_manager][:vehicle_turn_rate] < 100
    Process.sleep(200)
  end
end
