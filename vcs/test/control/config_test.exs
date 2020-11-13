defmodule Control.ConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    Common.Utils.common_startup()
    RingLogger.attach()
    model_type = "T28"
    MessageSorter.System.start_link(model_type)
    {:ok, [model_type: model_type]}
  end

  test "All test", context do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    config = Configuration.Module.get_config(Control, context[:model_type], "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:controller][:process_variable_cmd_loop_interval_ms] == Configuration.Generic.get_loop_interval_ms(:fast)
    Process.sleep(200)
  end
end
