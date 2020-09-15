defmodule MessageSorter.StartActuationSortersTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    MessageSorter.System.start_link(:Cessna)
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
    model_type = :Cessna
    actuation_sorters = Configuration.Module.Actuation.get_all_actuator_channels_and_names(model_type)
    indirect_actuator_cmds = MessageSorter.Sorter.get_value(:indirect_actuator_cmds)
    Logger.info("indirect: #{inspect(indirect_actuator_cmds)}")
    Enum.each(actuation_sorters.direct, fn {channel, name} ->
      sorter_value = MessageSorter.Sorter.get_value({:direct_actuator_cmds, name})
      Logger.info("sorter #{name}: #{sorter_value}")
    end)
    Process.sleep(200)
  end
end
