defmodule MessageSorter.ConfigTest do
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
    model_type = context[:model_type]
    config = Configuration.Module.get_config(MessageSorter, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert !is_nil(Enum.at(config[:sorter_configs],0)[:value_type])
    Process.sleep(200)
  end
end
