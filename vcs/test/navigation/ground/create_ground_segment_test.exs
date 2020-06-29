defmodule Navigation.Ground.CreateGroundSegmentTest do
  use ExUnit.Case
  require Logger

  @pos_vel_group {:pv_values, :position_velocity}

  setup do
    vehicle_type = :Plane
    node_type = :all
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    Comms.System.start_operator(__MODULE__)

    Configuration.Module.start_modules([Navigation], vehicle_type, node_type)
    # nav_config = Configuration.Module.Navigation.get_config(vehicle_type, nil)
    # Navigation.System.start_link(nav_config)
    Process.sleep(400)
    {:ok, []}
  end

  test "Move Vehicle Test" do
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    # navigation_config = context[:config]
    start_position = Navigation.Path.Mission.get_seatac_location()
    ground_mission = Navigation.Path.Mission.get_random_ground_mission(start_position)
    Navigation.PathManager.load_mission(ground_mission, __MODULE__)
    Process.sleep(100)
    # Move to start_location
    pos_vel = %{position: start_position, velocity: %{north: 1.0, east: 0, down: 0}}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.altitude == 0
    assert cmds.course_ground == 0
    Logger.info("goals 3: #{inspect(cmds)}")
    assert true
  end
end
