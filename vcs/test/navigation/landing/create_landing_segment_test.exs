defmodule Navigation.Ground.CreateLandingSegmentTest do
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
    max_pos_delta = 0.01
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    # navigation_config = context[:config]
    start_alt = 233.3
    finish_alt = 133.3
    start_position = Navigation.Path.Mission.get_seatac_location(start_alt)
    landing_mission = Navigation.Path.Mission.get_landing_mission()
    Navigation.PathManager.load_mission(landing_mission, __MODULE__)
    Process.sleep(1000)
    config_points = Navigation.PathManager.get_config_points()
    # Move to start_location
    Logger.info("move to start location")
    pos = Map.put(start_position, :agl, 100)
    speed = 1.0
    course = 0.0
    velocity = %{speed: speed, course: course, airspeed: speed}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(cmds.altitude, start_position.altitude, max_pos_delta)
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_flight),0, max_rad_delta)
    assert Enum.at(config_points,0).type == Navigation.Path.Waypoint.landing_type()
    Logger.info("goals 3: #{inspect(cmds)}")

    # Move down the runway, with speed
    Logger.info("move to  North")
    new_position = Common.Utils.Location.lla_from_point(start_position,200,0)
    |> Map.put(:agl, 100)
    pos = new_position
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    exp_alt_cmd = 233.3 - 50*(:math.cos(:math.pi*(1-200/1000)) + 1)
    assert_in_delta(cmds.altitude, exp_alt_cmd, max_pos_delta)
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_flight),0, max_rad_delta)
    # Move to the touchdown position
    Logger.info("move to ")
    new_position = Common.Utils.Location.lla_from_point(start_position,1000,0)
    |> Map.put(:altitude, 134.5)
    |> Map.put(:agl, 1.5)
    pos = new_position
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    exp_alt_cmd = 133.3
    assert_in_delta(cmds.altitude, exp_alt_cmd, max_pos_delta)
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_ground),0, max_rad_delta)
    assert_in_delta(cmds.speed,35,0.001)

    # Move past the touchdown position
    Logger.info("move towards stopping ")
    new_position = Common.Utils.Location.lla_from_point(start_position,1100,0)
    |> Map.put(:altitude, 134.0)
    |> Map.put(:agl, 1.0)
    pos = new_position
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    # Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    # Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, velocity, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    exp_alt_cmd = 133.3
    assert_in_delta(cmds.altitude, exp_alt_cmd, max_pos_delta)
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_ground),0, max_rad_delta)
    assert_in_delta(cmds.speed,0,0.001)


    # Move to the end the runway, with speed
    # # Speed up
    # Logger.info("same position but with 35m/s speed")
    # pos = new_position
    # speed = 35.0
    # Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, speed, course, 0}, @pos_vel_group, self())
    # Process.sleep(100)
    # cmds = MessageSorter.Sorter.get_value({:goals, 3})
    # Logger.info("goals 3: #{inspect(cmds)}")
    # assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_ground),0, max_rad_delta)
    # assert cmds.altitude > 0
    # assert Map.has_key?(cmds, :pitch) == false
    # # Climb above AGL threshold up
    # Logger.info("climb above AGL threshold")
    # new_position = Common.Utils.Location.lla_from_point(start_position,500,0)
    # |> Map.put(:agl, 5.3)
    # pos = new_position
    # speed = 37.0
    # Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos, speed, course, 0}, @pos_vel_group, self())
    # Process.sleep(100)
    # cmds = MessageSorter.Sorter.get_value({:goals, 3})
    # Logger.info("goals 3: #{inspect(cmds)}")
    # assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course_flight),0, max_rad_delta)
    # assert Map.has_key?(cmds, :pitch) == false
    # assert cmds.altitude > 0
  end
end
