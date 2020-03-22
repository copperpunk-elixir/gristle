defmodule Swarm.HealthySwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  test "Create healthy swarm" do
    Logger.info("Create healthy swarm")
    pid = Hb.test_setup()
    Hb.add_heartbeat(pid, 0, 1, 1000)
    Process.sleep(150)
    assert Hb.swarm_healthy?(pid) == false
    assert Hb.node_healthy?(pid, 0) == false
    Hb.add_heartbeat(pid, 1, 2, 1000)
    Hb.add_heartbeat(pid, 2, 3, 1000)
    Hb.add_heartbeat(pid, 3, 0, 1000)
    Process.sleep(150)
    assert Hb.node_healthy?(pid, 0) == true
    assert Hb.node_healthy?(pid, 1) == true
    assert Hb.node_healthy?(pid, 2) == true
    assert Hb.node_healthy?(pid, 3) == true
    assert Hb.swarm_healthy?(pid) == true
  end
end
