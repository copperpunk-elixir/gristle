defmodule Swarm.SetupTest do
  alias Swarm.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  test "create Hb server" do
    Logger.debug("Create Hb server")
    pid = Hb.test_setup()
    assert Hb.swarm_healthy?() == false
  end
end
