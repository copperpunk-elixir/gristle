defmodule Logging.ConfigTest do
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
    config = Configuration.Module.get_config(Logging, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:logger][:root_path] == Common.Utils.File.get_mount_path() <>  "/"
    Process.sleep(200)
  end
end
