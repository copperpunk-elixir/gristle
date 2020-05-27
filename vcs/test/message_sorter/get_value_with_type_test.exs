defmodule Workshop.MessageQueueTest  do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link(:Plane)
    {:ok, []}
  end

  test "Get Value with Type" do
    config = Configuration.Vehicle.Plane.Control.get_pv_cmds_sorter_configs()
    level_2_config = Enum.at(config, 1)
    sorter_name = {:pv_cmds, 2}
    # Start registry
    Comms.ProcessRegistry.start_link()
    Process.sleep(200)
    {current_cmds, current_cmd_status} = MessageSorter.Sorter.get_value_with_status(sorter_name)
    assert current_cmds.roll == level_2_config.default_value.roll
    assert current_cmds.pitch == level_2_config.default_value.pitch
    assert current_cmd_status == :default_value
    new_roll_value = 1.1
    new_pitch_value = -0.5
    new_cmds = Map.merge(current_cmds, %{roll: new_roll_value, pitch: new_pitch_value})
    MessageSorter.Sorter.add_message(sorter_name, [1],100,new_cmds)
    Process.sleep(50)
    {current_cmds, current_cmd_status} = MessageSorter.Sorter.get_value_with_status(sorter_name)
    assert current_cmds.roll == new_roll_value
    assert current_cmds.pitch == new_pitch_value
    assert current_cmd_status == :current
    Process.sleep(100)
    {current_cmds, current_cmd_status} = MessageSorter.Sorter.get_value_with_status(sorter_name)
    assert current_cmds.roll == level_2_config.default_value.roll
    assert current_cmds.pitch == level_2_config.default_value.pitch
    assert current_cmd_status == :default_value
  end
end
