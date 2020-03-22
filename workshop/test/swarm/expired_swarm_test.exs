defmodule Swarm.ExpiredSwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  test "Healthy swarm expires to unhealthy swarm" do
    Logger.info("Create temporarily healthy swarm")
    pid = Hb.test_setup()
    Process.sleep(100)
    Hb.add_heartbeat(pid, 0, 1, 500)
    Hb.add_heartbeat(pid, 1, 2, 500)
    Hb.add_heartbeat(pid, 2, 0, 200)
    Process.sleep(150)
    assert Hb.swarm_healthy?(pid) == true
    Process.sleep(150)
    assert Hb.node_healthy?(pid, 0) == true
    assert Hb.node_healthy?(pid, 1) == false
    assert Hb.node_healthy?(pid, 2) == false
    assert Hb.swarm_healthy?(pid) == false
  end

end
