defmodule Swarm.UnhealthySwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  test "Create unhealthy swarm" do
    Logger.info("Create unhealthy swarm")
    pid = Hb.test_setup()
    Hb.add_heartbeat(pid, 0, 1, 1000)
    Process.sleep(150)
    assert Hb.swarm_healthy?(pid) == false
    assert Hb.node_healthy?(pid, 0) == false
    Hb.add_heartbeat(pid, 1, 2, 1000)
    Hb.add_heartbeat(pid, 2, 3, 1000)
    Hb.add_heartbeat(pid, 4, 0, 1000)
    Process.sleep(150)
    assert Hb.node_healthy?(pid, 0) == true
    assert Hb.node_healthy?(pid, 1) == true
    assert Hb.node_healthy?(pid, 2) == false
    assert Hb.node_healthy?(pid, 4) == true
    assert Hb.swarm_healthy?(pid) == false
  end

end
