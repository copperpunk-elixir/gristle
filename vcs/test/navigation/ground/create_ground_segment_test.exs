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

    nav_config = Configuration.Module.Navigation.get_config(vehicle_type, nil)
    Navigation.System.start_link(nav_config)
    config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(config)
    Process.sleep(400)
    {:ok, [config: nav_config]}
  end

  test "Create Ground Mission Test", context do
    nav_config = context[:config]
    max_rad_delta = 0.0001
    max_pos_delta = 0.001
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    # navigation_config = context[:config]
    start_position = Navigation.Path.Mission.get_seatac_location()
    ground_mission = Navigation.Path.Mission.get_random_ground_mission()
    Navigation.PathManager.load_mission(ground_mission, __MODULE__)
    Process.sleep(1000)
    config_points = Navigation.PathManager.get_config_points()
    # Move to start_location
    Logger.info("move to start location")
    pos_vel = %{position: Map.put(start_position, :agl, 0), velocity: %{north: 1.0, east: 0, down: 0}}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.altitude == 0
    assert_in_delta(cmds.course_ground,0, max_rad_delta)
    assert Enum.at(config_points,0).type == Navigation.Path.Waypoint.ground_type()
    Logger.info("goals 3: #{inspect(cmds)}")
    # Move halfway down the runway, with speed
    Logger.info("move to 150m North")
    new_position = Common.Utils.Location.lla_from_point(start_position,300,0)
    |> Map.put(:agl, 0.3)
    pos_vel = %{position: new_position, velocity: %{north: 25.0, east: 0, down: 0}}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    assert_in_delta(cmds.altitude, 0, max_pos_delta)
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_ground),0, max_rad_delta)
    # Speed up
    Logger.info("same position but with 35m/s speed")
    pos_vel = %{position: new_position, velocity: %{north: 35.0, east: 0, down: 0}}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_ground),0, max_rad_delta)
    assert cmds.altitude > 0
    assert Map.has_key?(cmds, :pitch) == false
    # Climb above AGL threshold up
    Logger.info("climb above AGL threshold")
    new_position = Common.Utils.Location.lla_from_point(start_position,500,0)
    |> Map.put(:agl, 5.3)
    pos_vel = %{position: new_position, velocity: %{north: 37.0, east: 0, down: 0}}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_flight),0, max_rad_delta)
    assert Map.has_key?(cmds, :pitch) == false
    assert cmds.altitude > 0
  end
end
