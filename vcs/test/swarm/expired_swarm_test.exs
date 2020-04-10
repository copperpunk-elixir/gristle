defmodule Swarm.ExpiredSwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case

  test "Healthy swarm expires to unhealthy swarm" do
    IO.puts("Create temporarily healthy swarm")
    Hb.test_setup()
    Process.sleep(100)
    Hb.add_heartbeat(0, 1, 500)
    Hb.add_heartbeat(1, 2, 500)
    Hb.add_heartbeat(2, 0, 200)
    Process.sleep(150)
    assert Hb.swarm_healthy?() == true
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == false
    assert Hb.node_healthy?(2) == false
    assert Hb.swarm_healthy?() == false
  end

end
