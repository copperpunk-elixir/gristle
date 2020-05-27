defmodule Estimation.PublishPVValuesSlowLoop do
  use ExUnit.Case

  setup do
    config = Configuration.Generic.get_estimator_config()
    Estimation.System.start_link(config)
    MessageSorter.System.start_link(:Plane)
    Comms.TestMemberAllGroups.start_link()
    {:ok, [config: config]}
  end

  test "Receive INS messages" do
    # This is a visual test - Confirm that the INS Logger output matches the Estimator rx Logger output
    # Both in value and in desired rate
    command_config = %{
      commander: %{vehicle_type: :Plane},
      frsky_rx: %{publish_rx_output_loop_interval_ms: 1000}
    }
    Command.System.start_link(command_config)
    Process.sleep(3500)

    assert true
  end
end
