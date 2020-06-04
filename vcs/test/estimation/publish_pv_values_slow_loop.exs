defmodule Estimation.PublishPVValuesSlowLoop do
  use ExUnit.Case

  setup do
    vehicle_type = :Plane
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link(vehicle_type)
    Process.sleep(100)
    config = Configuration.Generic.get_estimator_config()
    Estimation.System.start_link(config)
    Comms.TestMemberAllGroups.start_link()
    command_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Command)
    {:ok, []}
  end

  test "Receive INS messages" do
    # This is a visual test - Confirm that the INS Logger output matches the Estimator rx Logger output
    # Both in value and in desired rate
    Process.sleep(1500)
    assert true
  end
end
