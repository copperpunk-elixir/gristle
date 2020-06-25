defmodule Navigation.MoveVehicleTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    Comms.System.start_operator(__MODULE__)
    nav_config = Configuration.Module.get_config(Navigation, vehicle_type, :all)
    Navigation.PathManager.start_link(nav_config.path_manager)
    Process.sleep(400)
    {:ok, [config: nav_config.path_manager]}
  end

  test "Move Vehicle Test", context do
    max_pos_delta = 0.00001
    max_vector_delta = 0.001
    max_rad_delta = 0.0001
    path_manager_config = context[:config]

    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    Logger.info("goals 3: #{inspect(cmds)}")
    current_mission = Navigation.Path.Mission.get_default_mission()
    Navigation.PathManager.load_mission(current_mission)
    Process.sleep(100)
    config_points = Navigation.PathManager.get_config_points()
    wp1 = Enum.at(current_mission.waypoints,0)


    dubins = Navigation.PathManager.get_dubins_for_cp(0)
    pcs = dubins.path_cases
    pci = 0
    pc = Enum.at(pcs, pci)
    # Starting at wp1
    pos_vel = %{
      position: %{latitude: wp1.latitude, longitude: wp1.longitude, altitude: wp1.altitude},
      velocity: %{north: 0, east: 3, down: 0}
    }
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.speed == 2
    assert_in_delta(cmds.course, :math.pi/2, max_rad_delta)

    # Move in the positive Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 0, 2)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.course < :math.pi/2
    # Move in the positive X direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 2, 0)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert cmds.course > :math.pi/2
# Check Line segment
    # Start at the beginning of the line
    pci = 2
    pc = Enum.at(pcs, pci)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 10, 10)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(cmds.course - 0), max_rad_delta)
    # Move in positive Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 10, 10.2)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) < 0
    # Move in negative Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 10, 9.8)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) > 0

   # Check Next orbit
    # Start at the end of the line
    pci = 3
    pc = Enum.at(pcs, pci)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 190, 10)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(cmds.course - 0), max_rad_delta)
    # Move in positive Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 190, 10.2)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) < 0
    # Move in negative Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 190, 9.8)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - 0) > 0
    # Check Next orbit
    pci = 4
    pc = Enum.at(pcs, pci)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 197.0707, 12.928932)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/4), max_rad_delta)
    # Move in positive X direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 202, 18)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2) > 0
  
    # Move in negative X direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 198, 18)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2) < 0

    # complete the CP
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 200, 20.00001)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert_in_delta(Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2),0, max_rad_delta)
    # Perform the next CP
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 200, 21)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 195, 25)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 80, 30)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 5, 30)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 0, 40.00001)
    pos_vel = %{pos_vel | position: %{pos_vel.position | latitude: lat, longitude: lon}}
    Navigation.PathManager.move_vehicle(pos_vel)
    Process.sleep(100)
    cmds = MessageSorter.Sorter.get_value({:goals, 3})
    assert Common.Utils.turn_left_or_right_for_correction(cmds.course - :math.pi/2) < 0
  end
end
