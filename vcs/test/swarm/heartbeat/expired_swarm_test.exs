defmodule Swarm.ExpiredSwarmTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    config = %{
      heartbeat: %{
        heartbeat_loop_interval_ms: 100
      }
    }
    Swarm.System.start_link(config)
    {:ok, []}
  end

  test "Healthy swarm expires to unhealthy swarm" do
    IO.puts("Create temporarily healthy swarm")
    Process.sleep(400)
    Hb.add_heartbeat(%{node: 0, ward: 1, state: :ready}, 500)
    Hb.add_heartbeat(%{node: 1, ward: 2, state: :ready}, 500)
    Hb.add_heartbeat(%{node: 2, ward: 0, state: :ready}, 200)
    Process.sleep(150)
    assert Hb.swarm_healthy?() == true
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == false
    assert Hb.node_healthy?(2) == false
    assert Hb.swarm_healthy?() == false
  end

end
