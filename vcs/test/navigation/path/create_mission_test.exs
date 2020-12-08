defmodule Navigation.Path.CreateMissionTest do
  use ExUnit.Case
  require Logger

  test "Create Waypoint" do
    speed = 10
    course = 0

    latlon1 = Common.Utils.LatLonAlt.new_deg(45.0, -120.0, 100)
    # North
    latlon2 = Common.Utils.LatLonAlt.new_deg(45.01, -120.0, 100)
    wp1 = Navigation.Path.Waypoint.new_flight(latlon1, speed, course, "wp1")
    wp2 = Navigation.Path.Waypoint.new_flight(latlon2, speed, course, "wp2")

    mission = Navigation.Path.Mission.new_mission("test", [wp1, wp2], :Plane)
    assert mission.name == "test"
    assert mission.waypoints == [wp1, wp2]

    latlon3 = Common.Utils.LatLonAlt.new_deg(45.01, -119.99, 100)
    wp3 = Navigation.Path.Waypoint.new_flight(latlon3, speed, course, "wp3")

    # Add waypoint at the end
    new_mission = Navigation.Path.Mission.add_waypoint_at_index(mission, wp3, -1)
    assert new_mission.waypoints == [wp1, wp2, wp3]

    # Add waypoint at the end in another way
    new_mission = Navigation.Path.Mission.add_waypoint_at_index(mission, wp3, 5)
    assert new_mission.waypoints == [wp1, wp2, wp3]

    # Add waypoint at the beginning
    new_mission = Navigation.Path.Mission.add_waypoint_at_index(mission, wp3, 0)
    assert new_mission.waypoints == [wp3, wp1, wp2]

    # Add waypoint with a bogus negative index
    # This waypoint should be ignored
    new_mission = Navigation.Path.Mission.add_waypoint_at_index(mission, wp3, -2)
    assert new_mission.waypoints == [wp1, wp2]

    # Add waypoint in the middle
    latlon4 = Common.Utils.LatLonAlt.new_deg(45.00, -119.99, 100)
    wp4 = Navigation.Path.Waypoint.new_flight(latlon4, speed, course, "wp4")
    new_mission = Navigation.Path.Mission.add_waypoint_at_index(mission, wp4, 1)
    assert new_mission.waypoints == [wp1, wp4, wp2]

    # Remove waypoint
    mission = Navigation.Path.Mission.new_mission("test1", [wp1, wp2, wp3, wp4], :Plane)
    new_mission = Navigation.Path.Mission.remove_waypoint_at_index(mission, 0)
    assert new_mission.waypoints == [wp2, wp3, wp4]

    # Remove all waypoints
    mission = Navigation.Path.Mission.new_mission("test1", [wp1, wp2, wp3, wp4], :Plane)
    new_mission = Navigation.Path.Mission.remove_all_waypoints(mission)
    assert new_mission.waypoints == []

  end

  test "Create Default Mission" do
    max_delta = 0.00001
    Navigation.Path.Mission.get_default_mission()
    assert true
  end

  test "Create Mission from current location" do
    vehicle_type = :Plane
    nav_config = Configuration.Module.get_config(Navigation, vehicle_type, :all)
    Navigation.System.start_link(nav_config)
    config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(config)
    Process.sleep(400)
    pos = %{latitude: 45.0, longitude: -120.0, altitude: 123.4}
    speed = 3.0
    airspeed = speed
    course = 0.3
    velocity = %{speed: speed, course: course, airspeed: airspeed}
    Comms.Operator.send_local_msg_to_group(__MODULE__,{{:pv_values, :position_velocity}, pos, velocity, 0}, self())
    Process.sleep(100)
    Navigation.Path.PathManager.load_from_current("Montague 1")
    Process.sleep(100000)
  end
end
