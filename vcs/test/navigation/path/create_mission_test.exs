defmodule Navigation.Path.CreateMissionTest do
  use ExUnit.Case
  require Logger

  test "Create Waypoint" do
    speed = 10
    course = 0

    latlon1 = Navigation.Utils.LatLonAlt.new_deg(45.0, -120.0, 100)
    # North
    latlon2 = Navigation.Utils.LatLonAlt.new_deg(45.01, -120.0, 100)
    wp1 = Navigation.Path.Waypoint.new_flight(latlon1, speed, course, "wp1")
    wp2 = Navigation.Path.Waypoint.new_flight(latlon2, speed, course, "wp2")

    mission = Navigation.Path.Mission.new_mission("test", [wp1, wp2], :Plane)
    assert mission.name == "test"
    assert mission.waypoints == [wp1, wp2]

    latlon3 = Navigation.Utils.LatLonAlt.new_deg(45.01, -119.99, 100)
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
    latlon4 = Navigation.Utils.LatLonAlt.new_deg(45.00, -119.99, 100)
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
end
