defmodule Peripherals.I2c.ConfigTest do
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
    config = Configuration.Module.get_config(Peripherals.I2c, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[Health.Ina260][:battery_type] == "cluster"
    assert config[Health.Ina219][:battery_type] == "cluster"
    assert config[Health.Sixfab][:battery_type] == "cluster"
    assert config[Health.Ads1015][:battery_type] == "motor"
    # assert config[Health.Ina219][:battery_type] == :cluster
    Process.sleep(200)
  end
end
