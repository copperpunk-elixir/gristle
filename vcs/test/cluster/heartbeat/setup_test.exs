defmodule Cluster.SetupTest do
  alias Cluster.Heartbeat, as: Hb
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    config = %{
      heartbeat: %{
        heartbeat_loop_interval_ms: 100
      }
    }
    Cluster.System.start_link(config)
    {:ok, []}
  end

  test "create Hb server" do
    IO.puts("Create Hb server")
    Process.sleep(400)
    assert Hb.cluster_healthy?() == false
  end
end
