defmodule Simulation.ReadUdpTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    Estimation.System.start_link(Configuration.Module.get_config(Estimation, vehicle_type, node_type))
    Display.Scenic.System.start_link(Configuration.Module.get_config(Display, vehicle_type, node_type))
    {:ok, []}
  end

  # test "Read UDP", context do
  #   Logger.info("Read UDP test")
  #   Simulation.XplaneReceive.start_link(Configuration.Module.Simulation.get_simulation_xplane_receive_config())
  #   Process.sleep(200000)
  # end
end
