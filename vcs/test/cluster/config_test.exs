defmodule Cluster.ConfigTest do
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
    config = Configuration.Module.get_config(Cluster, context[:model_type], "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[:heartbeat][:node] == -1
    assert config[:heartbeat][:ward] == -1
    assert config[:network][:src_port] == 8780
    Process.sleep(200)
  end
end
