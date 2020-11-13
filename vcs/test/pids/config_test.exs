defmodule Pids.ConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    Common.Utils.common_startup()
    RingLogger.attach()
    {:ok, []}
  end

  test "All test" do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    model_type = "T28"
    config = Configuration.Module.get_config(Pids, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:attitude_scalar][:roll_rollrate][:scale] == 2.0
    assert config[:pids][:rollrate][:aileron][:kp] == 0.1

    model_type = "T28Z2m"
    config = Configuration.Module.get_config(Pids, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:attitude_scalar][:roll_rollrate][:scale] == 2.0
    assert config[:pids][:rollrate][:aileron][:kp] == 0.1

    model_type = "Cessna"
    config = Configuration.Module.get_config(Pids, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:attitude_scalar][:roll_rollrate][:scale] == 2.0
    assert config[:pids][:rollrate][:aileron][:kp] == 0.6

    Process.sleep(200)
  end
end
