defmodule Cluster.HealthyClusterTest do
  alias Cluster.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    config = %{
      heartbeat: %{
        heartbeat_loop_interval_ms: 100,
        node: 0,
        ward: 1
      }
    }
    Cluster.System.start_link(config)
    {:ok, []}
  end

  test "Create healthy cluster" do
    Logger.info("Create healthy cluster")
    Process.sleep(400)
    assert Hb.cluster_healthy?() == false
    assert Hb.node_healthy?(0) == false
    Hb.add_heartbeat(%{node: 1, ward: 2,})
    Hb.add_heartbeat(%{node: 2, ward: 3})
    Hb.add_heartbeat(%{node: 3, ward: 0})
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == true
    assert Hb.node_healthy?(2) == true
    assert Hb.node_healthy?(3) == true
    assert Hb.cluster_healthy?() == true
  end
end
