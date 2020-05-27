defmodule Navigation.ProcessGoalsMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    Comms.Operator.start_link(%{name: __MODULE__})
    {:ok, []}
  end

  test "Check Goals message sorter for content" do
    vehicle_type = :Plane
    default_pv_cmds_level = 3
    config = %{navigator: %{vehicle_type: vehicle_type, navigator_loop_interval_ms: 100, default_pv_cmds_level: default_pv_cmds_level }}
    Navigation.System.start_link(config)
    Process.sleep(500)
    # Fake goals_output
    control_state_cmd = 2
    classification = [1, __MODULE__]
    time_validity_ms = 200
    goals = %{roll: 0.2, pitch: 1, yaw: -1, thrust: 0.5}
    Comms.Operator.send_global_msg_to_group(__MODULE__, {{:goals, control_state_cmd},classification, time_validity_ms,goals},{:goals, control_state_cmd}, self())
    Process.sleep(150)
    sorted_goal = MessageSorter.Sorter.get_value({:goals, control_state_cmd})
    assert sorted_goal.roll == goals.roll
    assert sorted_goal.pitch == goals.pitch
    # Let the commands expire
    Process.sleep(time_validity_ms)
    vehicle_module =Module.concat([Configuration.Vehicle, vehicle_type, Control])
    pv_list = apply(vehicle_module, :get_pv_cmds_sorter_configs, [])
    default_values = Enum.at(pv_list, control_state_cmd-1).default_value
    sorted_goal = MessageSorter.Sorter.get_value({:goals, control_state_cmd})
    assert sorted_goal.roll == default_values.roll

    # Verify that Navigator is sending messages
    pv_cmds_2 = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert pv_cmds_2.pitch == default_values.pitch
    # Until we send the a valid goals command, the Navigator should be using the default commands of
    # the default_pv_cmds_level
    control_state_current = MessageSorter.Sorter.get_value(:control_state)
    assert control_state_current == default_pv_cmds_level
    # Now send another valid command
    Comms.Operator.send_global_msg_to_group(__MODULE__, {{:goals, control_state_cmd},classification, 1000,goals},{:goals, control_state_cmd}, self())
    Process.sleep(200)
    pv_cmds_2 = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert pv_cmds_2.yaw == goals.yaw
    control_state_current = MessageSorter.Sorter.get_value(:control_state)
    assert control_state_current == control_state_cmd
  end
end
