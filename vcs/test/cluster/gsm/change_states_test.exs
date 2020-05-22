defmodule Cluster.Gsm.ChangeStatesTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "Change states" do
    IO.puts("ClusterGsm: Change states")
    config = %{
      gsm: %{
        modules_to_monitor: [:estimator],
        state_loop_interval_ms: 200
      }
    }
    Cluster.System.start_link(config)
    Process.sleep(300)
    new_state = 2
    Cluster.Gsm.add_desired_control_state(new_state, [0], 300)
    Process.sleep(250)
    assert Cluster.Gsm.get_state() == new_state
    # State should hold even after it expires
    Process.sleep(200)
    assert Cluster.Gsm.get_state() == new_state
  end
end
