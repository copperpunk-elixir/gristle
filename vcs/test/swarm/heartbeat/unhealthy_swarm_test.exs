defmodule Swarm.UnhealthySwarmTest do
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

  test "Create unhealthy swarm" do
    IO.puts("Create unhealthy swarm")
    Process.sleep(400)
    Hb.add_heartbeat(%{node: 0, ward: 1, state: :disarmed}, 1000)
    Process.sleep(150)
    assert Hb.swarm_healthy?() == false
    assert Hb.node_healthy?(0) == false
    Hb.add_heartbeat(%{node: 1, ward: 2, state: :disarmed}, 1000)
    Hb.add_heartbeat(%{node: 2, ward: 3, state: :disarmed}, 1000)
    Hb.add_heartbeat(%{node: 4, ward: 0, state: :disarmed}, 1000)
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == true
    assert Hb.node_healthy?(2) == false
    assert Hb.node_healthy?(4) == true
    assert Hb.swarm_healthy?() == false
  end

end