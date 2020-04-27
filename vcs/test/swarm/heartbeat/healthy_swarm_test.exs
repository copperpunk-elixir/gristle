defmodule Swarm.HealthySwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    config = %{
      heartbeat: %{
        heartbeat_loop_interval_ms: 100,
        node: 0,
        ward: 1
      }
    }
    Swarm.System.start_link(config)
    {:ok, []}
  end

  test "Create healthy swarm" do
    Logger.info("Create healthy swarm")
    Process.sleep(400)
    assert Hb.swarm_healthy?() == false
    assert Hb.node_healthy?(0) == false
    Hb.add_heartbeat(%{node: 1, ward: 2,}, 1000)
    Hb.add_heartbeat(%{node: 2, ward: 3}, 1000)
    Hb.add_heartbeat(%{node: 3, ward: 0}, 1000)
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == true
    assert Hb.node_healthy?(2) == true
    assert Hb.node_healthy?(3) == true
    assert Hb.swarm_healthy?() == true
  end
end
