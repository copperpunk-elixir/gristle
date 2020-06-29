defmodule Navigation.CreatePathManagerTest do
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
    max_vector_delta = 0.001
    path_manager_config = context[:config]
    turn_rate = path_manager_config.vehicle_turn_rate
    # current_mission = Navigation.PathManager.get_mission()
    # assert current_mission == nil
    current_mission = Navigation.Path.Mission.get_default_mission()
    Navigation.PathManager.load_mission(current_mission, __MODULE__)
    Process.sleep(100)
    # current_mission = Navigation.PathManager.get_mission()
    assert current_mission.name == "default"

    config_points = Navigation.PathManager.get_config_points()
    # Logger.info("config points: #{inspect(config_points)}")
    # assert length(config_points) == length(current_mission.waypoints)-1

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

    # assert_in_delta(cp1.cs.latitude, exp_cs1_lat, max_pos_delta)
    # assert_in_delta(cp1.cs.longitude, exp_cs1_lon, max_pos_delta)
    # assert_in_delta(cp2.cs.latitude, exp_cs2_lat, max_pos_delta)
    # assert_in_delta(cp2.cs.longitude, exp_cs2_lon, max_pos_delta)
    # assert_in_delta(cp3.cs.latitude, exp_cs3_lat, max_pos_delta)
    # assert_in_delta(cp3.cs.longitude, exp_cs3_lon, max_pos_delta)

    # exp_dist = 180 + 180 + 90 + 80 + 9/4*2*cs1_rad*:math.pi
    # assert_in_delta(Navigation.PathManager.get_current_path_distance(), exp_dist, 0.01)

    # # Config Point 1
    # dubins = Navigation.PathManager.get_dubins_for_cp(0)
    # [pc0, pc1, pc2, pc3, pc4] = dubins.path_cases
    # assert_in_delta(pc0.q.x, -1, max_vector_delta)
    # assert_in_delta(pc0.q.y, 0, max_vector_delta)
    # assert_in_delta(pc1.q.x, 1, max_vector_delta)
    # assert_in_delta(pc1.q.y, 0, max_vector_delta)
    # {rx, ry} = Common.Utils.Location.dx_dy_between_points(wp1, pc2.r)
    # {zix, ziy} = Common.Utils.Location.dx_dy_between_points(wp1, pc2.zi)
    # assert_in_delta(rx, 10, max_vector_delta)
    # assert_in_delta(ry, 10, max_vector_delta)
    # assert_in_delta(zix, 190, max_vector_delta)
    # assert_in_delta(ziy, 10, max_vector_delta)
    # assert_in_delta(pc3.q.x, 0, max_vector_delta)
    # assert_in_delta(pc3.q.y, -1, max_vector_delta)
    # assert_in_delta(pc4.q.x, 0, max_vector_delta)
    # assert_in_delta(pc4.q.y, 1, max_vector_delta)
    # # Config Point 3
    # dubins = Navigation.PathManager.get_dubins_for_cp(2)
    # [pc0, pc1, pc2, pc3, pc4] = dubins.path_cases
    # assert_in_delta(pc0.q.x, -1, max_vector_delta)
    # assert_in_delta(pc0.q.y, 0, max_vector_delta)
    # assert_in_delta(pc1.q.x, 1, max_vector_delta)
    # assert_in_delta(pc1.q.y, 0, max_vector_delta)
    # {rx, ry} = Common.Utils.Location.dx_dy_between_points(wp1, pc2.r)
    # {zix, ziy} = Common.Utils.Location.dx_dy_between_points(wp1, pc2.zi)
    # assert_in_delta(rx, 10, max_vector_delta)
    # assert_in_delta(ry, 50, max_vector_delta)
    # assert_in_delta(zix, 100, max_vector_delta)
    # assert_in_delta(ziy, 50, max_vector_delta)
    # assert_in_delta(pc3.q.x, 1, max_vector_delta)
    # assert_in_delta(pc3.q.y, 0, max_vector_delta)
    # assert_in_delta(pc4.q.x, -1, max_vector_delta)
    # assert_in_delta(pc4.q.y, 0, max_vector_delta)

    # # Config Point 4
    # dubins = Navigation.PathManager.get_dubins_for_cp(3)
    # [pc0, pc1, pc2, pc3, pc4] = dubins.path_cases
    # assert_in_delta(pc0.q.x, 0, max_vector_delta)
    # assert_in_delta(pc0.q.y, 1, max_vector_delta)
    # assert_in_delta(pc1.q.x, 0, max_vector_delta)
    # assert_in_delta(pc1.q.y, -1, max_vector_delta)
    # {rx, ry} = Common.Utils.Location.dx_dy_between_points(wp1, pc2.r)
    # {zix, ziy} = Common.Utils.Location.dx_dy_between_points(wp1, pc2.zi)
    # assert_in_delta(rx, 90, max_vector_delta)
    # assert_in_delta(ry, 20, max_vector_delta)
    # assert_in_delta(zix, 90, max_vector_delta)
    # assert_in_delta(ziy, -60, max_vector_delta)
    # assert_in_delta(pc3.q.x, -1, max_vector_delta)
    # assert_in_delta(pc3.q.y, 0, max_vector_delta)
    # assert_in_delta(pc4.q.x, 1, max_vector_delta)
    # assert_in_delta(pc4.q.y, 0, max_vector_delta)

    # # Path completion for CP3 (index 2)
    # dubins = Navigation.PathManager.get_dubins_for_cp(2)
    # pcs = dubins.path_cases
    # cp = Enum.at(config_points, 2)
    # pci = 0
    # pc = Enum.at(pcs,pci)
    # # When we start, we can skip case 0
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,1,39)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # pc = Enum.at(pcs, pci)
    # assert pci==1
    # # At the same point, we should not advance to case 1
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # assert pci==1
    # # Move again, but not past the line
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,9,55)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # assert pci==1
    # # Cross the line
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,11,53)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # pc = Enum.at(pcs, pci)
    # assert pci==2
    # # Move short of the next line
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,99,53)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # assert pci==2
    # # Cross the line
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,101,53)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # pc = Enum.at(pcs, pci)
    # assert pci==3
    # # If somehow we moved backwards, confirm that we haven't advanved cases
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,98,53)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # assert pci==3
    # # Cross the line (which is the same on as for case 2)
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,102,33)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # pc = Enum.at(pcs, pci)
    # assert pci==4
    # # Complete the path
    # {lat, lon} = Common.Utils.Location.lat_lon_from_point(wp1.latitude, wp1.longitude,97,30)
    # pos = Navigation.Utils.LatLonAlt.new(lat, lon)
    # pci = Navigation.PathManager.check_for_path_case_completion(pos, cp, pc)
    # assert pci==0
  end
end
