defmodule Swarm.UnhealthySwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  test "Create unhealthy swarm" do
    Logger.info("Create unhealthy swarm")
    Hb.test_setup()
    Hb.add_heartbeat(0, 1, 1000)
    Process.sleep(150)
    assert Hb.swarm_healthy?() == false
    assert Hb.node_healthy?(0) == false
    Hb.add_heartbeat(1, 2, 1000)
    Hb.add_heartbeat(2, 3, 1000)
    Hb.add_heartbeat(4, 0, 1000)
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == true
    assert Hb.node_healthy?(2) == false
    assert Hb.node_healthy?(4) == true
    assert Hb.swarm_healthy?() == false
  end

end
