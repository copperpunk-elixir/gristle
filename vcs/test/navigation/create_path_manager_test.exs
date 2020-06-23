defmodule Navigation.ProcessGoalsMessageTest do
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

  test "Create Path Manager", context do
    max_pos_delta = 0.00001
    path_manager_config = context[:config]
    turn_rate = path_manager_config.vehicle_turn_rate
    current_mission = Navigation.PathManager.get_mission()
    assert current_mission == nil
    Navigation.PathManager.load_mission(Navigation.Path.Mission.get_default_mission())
    Process.sleep(100)
    current_mission = Navigation.PathManager.get_mission()
    assert current_mission.name == "default"

    config_points = Navigation.PathManager.get_config_points()
    # Logger.info("config points: #{inspect(config_points)}")
    assert length(config_points) == length(current_mission.waypoints)-1

    cp1 = Enum.at(config_points, 0)
    cp2 = Enum.at(config_points, 1)
    cp3 = Enum.at(config_points, 2)
    wp1 = Enum.at(current_mission.waypoints,0)
    wp2 = Enum.at(current_mission.waypoints,1)
    wp3 = Enum.at(current_mission.waypoints,2)
    # assert_in_delta(cp1.pos.latitude, wp1.latitude, max_pos_delta)
    cs1_rad = wp1.speed/turn_rate
    {exp_cs1_lat, exp_cs1_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(wp1.latitude, wp1.longitude, cs1_rad, 0)

    cs2_rad = wp2.speed/turn_rate
    {exp_cs2_lat, exp_cs2_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(wp2.latitude, wp2.longitude, cs2_rad, :math.pi/2)

    cs3_rad = wp3.speed/turn_rate
    {exp_cs3_lat, exp_cs3_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(wp3.latitude, wp3.longitude, cs3_rad, :math.pi/2)

    assert_in_delta(cp1.cs.latitude, exp_cs1_lat, max_pos_delta)
    assert_in_delta(cp1.cs.longitude, exp_cs1_lon, max_pos_delta)
    assert_in_delta(cp2.cs.latitude, exp_cs2_lat, max_pos_delta)
    assert_in_delta(cp2.cs.longitude, exp_cs2_lon, max_pos_delta)
    assert_in_delta(cp3.cs.latitude, exp_cs3_lat, max_pos_delta)
    assert_in_delta(cp3.cs.longitude, exp_cs3_lon, max_pos_delta)

    exp_dist = 180 + 180 + 90 + 80 + 9/4*2*cs1_rad*:math.pi
    assert_in_delta(Navigation.PathManager.get_current_path_distance(), exp_dist, 0.01)

  end
end
