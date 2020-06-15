defmodule Pids.BoundedCorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    {:ok, []}
  end

  test "Read UDP", context do
    Logger.info("Read UDP test")
    xplane_config = %{port: 49000}
    Simulation.Xplane.start_link(xplane_config)
    Process.sleep(200)

    sim_output = Simulation.Xplane.get_output()
    assert Enum.empty?(sim_output) == false

  end
end
