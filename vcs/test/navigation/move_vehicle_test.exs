defmodule Navigation.MoveVehicleTest do
  use ExUnit.Case
  require Logger

  @pos_vel_group {:pv_values, :position_velocity}
  setup do
    vehicle_type = :Plane
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    Comms.System.start_operator(__MODULE__)
    nav_config = Configuration.Module.get_config(Navigation, vehicle_type, :all)
    Navigation.PathManager.start_link(nav_config.path_manager)
    display_config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(display_config)
    Process.sleep(400)
    {:ok, [config: nav_config.path_manager]}
  end

  test "Move Vehicle Test", context do
    max_pos_delta = 0.00001
    max_rad_delta = 0.0001
    path_manager_config = context[:config]

    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    current_mission = Navigation.Path.Mission.get_default_mission()
    Navigation.PathManager.load_mission(current_mission, __MODULE__)
    Process.sleep(100)
    config_points = Navigation.PathManager.get_config_points()
    wp1 = Enum.at(current_mission.waypoints,0)


    # Starting at wp1
    pos_vel = %{
      position: %{latitude: wp1.latitude, longitude: wp1.longitude, altitude: wp1.altitude},
      velocity: %{north: 0, east: 3, down: 0}
    }
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.speed == 0.8
    assert_in_delta(cmds.course, :math.pi/2, max_rad_delta)

    # Move in the positive Y direction
    pos = Common.Utils.Location.lla_from_point(wp1, 0, 2)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel,0}, @pos_vel_group, self())

    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.course < :math.pi/2
    # Move in the positive X direction
    pos = Common.Utils.Location.lla_from_point(wp1, 2, 0)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.course > :math.pi/2
# Check Line segment
    # Start at the beginning of the line
    pos = Common.Utils.Location.lla_from_point(wp1, 10, 10)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(cmds.course - 0), max_rad_delta)
    # Move in positive Y direction
    pos = Common.Utils.Location.lla_from_point(wp1, 10, 10.2)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) < 0
    # Move in negative Y direction
    pos = Common.Utils.Location.lla_from_point(wp1, 10, 9.8)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) > 0

   # Check Next orbit
    # Start at the end of the line
    pos = Common.Utils.Location.lla_from_point(wp1, 190, 10)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(cmds.course - 0), max_rad_delta)
    # Move in positive Y direction
    pos = Common.Utils.Location.lla_from_point(wp1, 190, 10.2)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) < 0
    # Move in negative Y direction
    pos = Common.Utils.Location.lla_from_point(wp1, 190, 9.8)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) > 0
    # Check Next orbit
    pos = Common.Utils.Location.lla_from_point(wp1, 197.07107, 12.928932)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/4), max_rad_delta)
    # Move in positive X direction
    pos = Common.Utils.Location.lla_from_point(wp1, 202, 18)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2) > 0

    # Move in negative X direction
    pos = Common.Utils.Location.lla_from_point(wp1, 198, 18)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2) < 0

    # complete the CP
    pos = Common.Utils.Location.lla_from_point(wp1, 200, 20.00001)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2),0, max_rad_delta)
    # Perform the next CP
    pos = Common.Utils.Location.lla_from_point(wp1, 200, 21)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    pos = Common.Utils.Location.lla_from_point(wp1, 195, 25)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    pos = Common.Utils.Location.lla_from_point(wp1, 80, 30)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    pos = Common.Utils.Location.lla_from_point(wp1, 5, 30)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    pos = Common.Utils.Location.lla_from_point(wp1, 0, 40.00001)
    pos_vel = %{pos_vel | position: pos}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{@pos_vel_group, pos_vel, 0}, @pos_vel_group, self())
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2) < 0
  end
end
