defmodule Pids.BoundedCorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    Estimation.System.start_link(Configuration.Generic.get_estimator_config())
    Display.Scenic.System.start_link(Configuration.Generic.get_display_config(vehicle_type))
    {:ok, []}
  end

  test "Read UDP", context do
    Logger.info("Read UDP test")
    Simulation.XplaneReceive.start_link(Configuration.Generic.get_simulation_xplane_receive_config())
    Process.sleep(200000)
  end
end
