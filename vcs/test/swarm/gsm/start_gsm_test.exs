defmodule Swarm.Gsm.StartGsmTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "Start GSM" do
    IO.puts("SwarmGsm: Start Gsm")
    Swarm.System.start_link()
    assert Swarm.Gsm.get_state() == :disarmed
  end

end
