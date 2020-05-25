defmodule Navigation.ProcessGoalsMessageTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    Comms.Operator.start_link(%{name: __MODULE__})
    {:ok, []}
  end

  test "Check Goals message sorter for content" do
    vehicle_type = :Plane
    config = %{navigator: %{vehicle_type: vehicle_type, navigator_loop_interval_ms: 100 }}
    Navigation.System.start_link(config)
    Process.sleep(500)
    # Fake goals_output
    control_state = 2
    classification = [1, __MODULE__]
    time_validity_ms = 200
    goals = %{roll: 0.2, pitch: 1, yaw: -1, thrust: 0.5}
    Comms.Operator.send_global_msg_to_group(__MODULE__, {{:goals, control_state},classification, time_validity_ms,goals},{:goals, control_state}, self())
    Process.sleep(150)
    sorted_goal = MessageSorter.Sorter.get_value({:goals, control_state})
    Logger.warn("sorted goal: #{inspect(sorted_goal)}")
    assert sorted_goal.roll == goals.roll
    assert sorted_goal.pitch == goals.pitch
    # Let the commands expire
    Process.sleep(time_validity_ms)
    vehicle_module =Module.concat([Vehicle, vehicle_type])
    pv_list = apply(vehicle_module, :get_process_variable_list, [])
    default_values = Enum.at(pv_list, control_state-1).default_value
    sorted_goal = MessageSorter.Sorter.get_value({:goals, control_state})
    assert sorted_goal.roll == default_values.roll

    # Join Start PV_cmds group and verity that Navigator is sending messages
    apply(vehicle_module, :start_pv_cmds_message_sorters, [])
    Process.sleep(500)
    pv_cmds_2 = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert pv_cmds_2.pitch == default_values.pitch
    Comms.Operator.send_global_msg_to_group(__MODULE__, {{:goals, control_state},classification, 1000,goals},{:goals, control_state}, self())
    Process.sleep(200)
    pv_cmds_2 = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert pv_cmds_2.pitch == goals.pitch
  end
end
