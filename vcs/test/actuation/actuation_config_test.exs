defmodule Actuation.ActuationConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    vehicle_type = :Plane
    node_type = :sim
    MessageSorter.System.start_link(vehicle_type)
    modules = [Actuation]
    Configuration.Module.start_modules(modules, vehicle_type, node_type)

    {:ok, []}
  end

  test "Combined with FrSky test" do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    config = Configuration.Module.get_config(Actuation, :Plane, :sim)
    Enum.each(config.sw_interface.actuators, fn actuator ->
      Logger.debug("#{inspect(actuator)}")
    end)
    # Logger.info("config: #{inspect(config)}")
    Process.sleep(2000)
  end
end
