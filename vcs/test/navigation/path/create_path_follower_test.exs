defmodule Navigation.Path.CreatePathFollowerTest do
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


  test "Create Path Follower" do
    max_rad_delta = 0.0001
    pf = Navigation.Path.PathFollower.new(0.12, 2.05, 0.52)
    assert_in_delta(pf.chi_inf_over_two_pi, 0.52*0.5/:math.pi,max_rad_delta)

    Navigation.PathManager.load_mission(Navigation.Path.Mission.get_default_mission(), __MODULE__)
    Process.sleep(100)
    current_mission = Navigation.Path.Mission.get_default_mission()
    config_points = Navigation.PathManager.get_config_points()
    wp1 = Enum.at(current_mission.waypoints,0)


    dubins = Navigation.PathManager.get_dubins_for_cp(0)
    pcs = dubins.path_cases
    pci = 0
    pc = Enum.at(pcs, pci)
    # Starting at wp1
    Navigation.Path.PathFollower.follow(pf, wp1, :math.pi/2, 0, pc)
    # Move in the positive Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 0, 2)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), -0.1 + :math.pi/2, 0, pc)
    assert course < :math.pi/2
    # Move in the positive X direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 2, 0)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), 0.1 + :math.pi/2, 0, pc)
    assert course > :math.pi/2

    # Check Line segment
    # Start at the beginning of the line
    pci = 2
    pc = Enum.at(pcs, pci)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 10, 10)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(course - 0), max_rad_delta)
    # Move in positive Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 10, 10.2)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert Common.Utils.turn_left_or_right_for_correction(course - 0) < 0
    # Move in negative Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 10, 9.8)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert Common.Utils.turn_left_or_right_for_correction(course - 0) > 0

   # Check Next orbit
    # Start at the end of the line
    pci = 3
    pc = Enum.at(pcs, pci)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 190, 10)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(course - 0), max_rad_delta)
    # Move in positive Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 190, 10.2)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert Common.Utils.turn_left_or_right_for_correction(course - 0) < 0
    # Move in negative Y direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 190, 9.8)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert Common.Utils.turn_left_or_right_for_correction(course - 0) > 0
    # Check Next orbit
    pci = 4
    pc = Enum.at(pcs, pci)
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 197.0707, 12.928932)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert_in_delta(0, Common.Utils.turn_left_or_right_for_correction(course - :math.pi/4), max_rad_delta)
    # Move in positive X direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 202, 18)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert Common.Utils.turn_left_or_right_for_correction(course - :math.pi/2) > 0

    # Move in negative X direction
    {lat,lon} = Common.Utils.Location.lat_lon_from_point(wp1, 198, 18)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, Navigation.Utils.LatLonAlt.new(lat,lon), :math.pi/4, 0, pc)
    assert Common.Utils.turn_left_or_right_for_correction(course - :math.pi/2) < 0
  end
end
