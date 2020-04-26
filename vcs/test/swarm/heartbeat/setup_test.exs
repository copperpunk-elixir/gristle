defmodule Swarm.SetupTest do
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

  test "create Hb server" do
    IO.puts("Create Hb server")
    assert Hb.swarm_healthy?() == false
  end
end
