defmodule Swarm.Gsm.StartGsmTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link() 
    {:ok, []}
  end

  test "Start GSM" do
    IO.puts("SwarmGsm: Start Gsm")
    initial_state= :disarmed
    Swarm.Gsm.start_link(%{initial_state: initial_state})
    assert Swarm.Gsm.get_state() == initial_state
  end

end
