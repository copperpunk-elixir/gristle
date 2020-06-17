defmodule MessageSorter.StartAllMessageSortersTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    MessageSorter.System.start_link(:Plane)
    {:ok, []}
  end

  test "Start all message sorters" do
    vehicle_type = :Plane
    # all_configs = MessageSorter.System.get_all_children(vehicle_type)
    # IO.inspect(all_configs)
    # Enum.each(all_configs, fn {module, config} ->
    #   Logger.info("module/config: #{module}/#{inspect(config)}")
    #   MessageSorter.System.start_sorter(config)
    # end)
    # Process.sleep(200)
    # Get value from sorter
    # Enum.each(all_configs, fn child_spec ->
    #   config = elem(child_spec.start,2)
    #   |> Enum.at(0)
    #   {value, value_status} = MessageSorter.Sorter.get_value_with_status(config.name)
    #   Logger.debug("sorter #{inspect(config.name)} has value #{inspect(value)} from status #{value_status}")
    # end)
    Process.sleep(200)
    {actuator_cmds, actuator_cmds_status} = MessageSorter.Sorter.get_value_with_status(:actuator_cmds)
    assert actuator_cmds.aileron == 0.5
    assert actuator_cmds_status == :default_value
  end
end
