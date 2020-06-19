defmodule Navigation.Mission.CreateMissionTest do
  use ExUnit.Case
  require Logger

  test "Create Waypoint" do
    dist_delta = 0.1
    speed = 10
    course = 0
    alt = 100

    lat1 = Common.Utils.Math.deg2rad(45.00)
    lon1 = Common.Utils.Math.deg2rad(-120.0)
    # North
    lat2 = Common.Utils.Math.deg2rad(45.01)
    lon2 = Common.Utils.Math.deg2rad(-120.0)
    wp1 = Navigation.Waypoint.new_waypoint(lat1, lon1, speed, course, alt, "wp1")
    wp2 = Navigation.Waypoint.new_waypoint(lat2, lon2, speed, course, alt, "wp2")

    mission = Navigation.Mission.new_mission("test", [wp1, wp2])
    assert mission.name == "test"
    assert mission.waypoints == [wp1, wp2]

    lat3 = Common.Utils.Math.deg2rad(45.01)
    lon3 = Common.Utils.Math.deg2rad(-119.99)
    wp3 = Navigation.Waypoint.new_waypoint(lat3, lon3, speed, course, alt, "wp3")

    # Add waypoint at the end
    new_mission = Navigation.Mission.add_waypoint_at_index(mission, wp3, -1)
    assert new_mission.waypoints == [wp1, wp2, wp3]

    # Add waypoint at the end in another way
    new_mission = Navigation.Mission.add_waypoint_at_index(mission, wp3, 5)
    assert new_mission.waypoints == [wp1, wp2, wp3]

    # Add waypoint at the beginning
    new_mission = Navigation.Mission.add_waypoint_at_index(mission, wp3, 0)
    assert new_mission.waypoints == [wp3, wp1, wp2]

    # Add waypoint with a bogus negative index
    # This waypoint should be ignored
    new_mission = Navigation.Mission.add_waypoint_at_index(mission, wp3, -2)
    assert new_mission.waypoints == [wp1, wp2]

    # Add waypoint in the middle
    lat4 = Common.Utils.Math.deg2rad(45.01)
    lon4 = Common.Utils.Math.deg2rad(-119.99)
    wp4 = Navigation.Waypoint.new_waypoint(lat4, lon4, speed, course, alt, "wp4")
    new_mission = Navigation.Mission.add_waypoint_at_index(mission, wp4, 1)
    assert new_mission.waypoints == [wp1, wp4, wp2]

    # Remove waypoint
    mission = Navigation.Mission.new_mission("test1", [wp1, wp2, wp3, wp4])
    new_mission = Navigation.Mission.remove_waypoint_at_index(mission, 0)
    assert new_mission.waypoints == [wp2, wp3, wp4]

    # Remove all waypoints
    mission = Navigation.Mission.new_mission("test1", [wp1, wp2, wp3, wp4])
    new_mission = Navigation.Mission.remove_all_waypoints(mission)
    assert new_mission.waypoints == []

  end
end
