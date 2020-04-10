defmodule Swarm.SetupTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case

  test "create Hb server" do
    IO.puts("Create Hb server")
    pid = Hb.test_setup()
    assert Hb.swarm_healthy?() == false
  end
end
