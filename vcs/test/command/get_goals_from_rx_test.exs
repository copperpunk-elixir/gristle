defmodule Command.GetGoalsFromRxTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    {:ok, []}
  end

  test "Get Channel 0 from FrSky interface" do
    Command.Commander.start_link(%{vehicle_type: :Plane})
    Process.sleep(4000)
    rollrate_cmd = Command.Commander.get_cmd(1,:rollrate)
    assert rollrate_cmd > 0.50
  end
end
