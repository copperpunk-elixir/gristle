defmodule Swarm.Gsm.StartGsmTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    {:ok, []}
  end

  test "Check state enums" do
    IO.puts("SwarmGsm: Check State Enums")
    state_map = Swarm.Gsm.get_state_map()
    assert state_map.disarmed == 0
    assert state_map.attitude == 3
    initial_state= :disarmed
    {:ok, pid} = Swarm.Gsm.start_link(%{initial_state: initial_state})
    assert Swarm.Gsm.get_state() == Swarm.Gsm.get_state_enum(initial_state)
  end

end
