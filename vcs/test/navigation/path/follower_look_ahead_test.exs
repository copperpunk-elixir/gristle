defmodule Navigation.Path.FollowerLookAheadTest do
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
    pf = Navigation.Path.PathFollower.new(0.10, 2.0, 0.5)
    assert_in_delta(pf.chi_inf_two_over_pi, 0.5*2.0/:math.pi,max_rad_delta)

    Navigation.PathManager.load_mission(Navigation.Path.Mission.get_default_mission(), __MODULE__)
    Process.sleep(100)
    current_mission = Navigation.Path.Mission.get_default_mission()
    config_points = Navigation.PathManager.get_config_points()
    wp1 = Enum.at(current_mission.waypoints,0)


    dubins = Navigation.PathManager.get_dubins_for_cp(0)
    pcs = dubins.path_cases
    pci = 0
    pc = Enum.at(pcs, pci)
    speed = 1.0
    # Starting at wp1
    latlon = Common.Utils.Location.lla_from_point(wp1, 0, 0)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, latlon, :math.pi/2,speed, pc)
    assert Common.Utils.Motion.turn_left_or_right_for_correction(course-:math.pi/2) < 0
    latlon = Common.Utils.Location.lla_from_point(wp1, -1, 0)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, latlon, 0, speed, pc)
    assert Common.Utils.Motion.turn_left_or_right_for_correction(course-:math.pi/2) > 0

    pci = 2
    pc = Enum.at(pcs,pci)
    latlon = Common.Utils.Location.lla_from_point(wp1, 10, 10)
    Navigation.Path.PathFollower.follow(pf, wp1, 0, 0, pc)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, latlon, 0, speed, pc)
    assert_in_delta(Common.Utils.Motion.turn_left_or_right_for_correction(course-0),0,max_rad_delta)
    latlon = Common.Utils.Location.lla_from_point(wp1, 10, 10.01)
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, latlon, 0,speed, pc)
    assert Common.Utils.Motion.turn_left_or_right_for_correction(course-0) < 0
    {_speed, course, _alt} = Navigation.Path.PathFollower.follow(pf, latlon, -:math.pi/2,speed, pc)
    assert Common.Utils.Motion.turn_left_or_right_for_correction(course-0) > 0

  end
end
