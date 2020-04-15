defmodule Swarm.Gsm.ChangeStatesTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "Change states" do
    IO.puts("SwarmGsm: Change states")
    initial_data = %{
      modules_to_monitor: [:estimator],
      state_loop_interval_ms: 200
    }
    initial_state= :disarmed
    config = Map.put(initial_data, :initial_state, initial_state)
    Swarm.Gsm.start_link(config)
    Process.sleep(300)
    new_state = Swarm.Gsm.get_state_enum(:semi_auto)
    Swarm.Gsm.add_desired_control_state(new_state, [0], 300)
    Process.sleep(250)
    assert Swarm.Gsm.get_state() == new_state
    # State should hold even after it expires
    Process.sleep(200)
    assert Swarm.Gsm.get_state() == new_state
  end
end
