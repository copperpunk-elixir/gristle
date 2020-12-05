defmodule Navigation.Waypoint.CreateWaypointTest do
  use ExUnit.Case
  require Logger

  test "Create Waypoint" do
    dist_range = 0.1
    Logger.info("Create Waypoint Test")
    speed = 10
    course = 0
    alt = 100
    latlon1 = Common.Utils.LatLonAlt.new_deg(45.0, -120.0, alt)
    # North
    latlon2 = Common.Utils.LatLonAlt.new_deg(45.01, -120.0, alt)
    wp1 = Navigation.Path.Waypoint.new_flight(latlon1, speed, course)
    wp2 = Navigation.Path.Waypoint.new_flight(latlon2, speed, course)
   {dx, dy} = Common.Utils.Location.dx_dy_between_points(wp1, wp2)
   # Logger.debug("dx/dy: #{dx}/#{dy}")
   assert_in_delta(dx, 1112, dist_range)
   assert_in_delta(dy, 0, dist_range)

   # West
   wp2 = %{wp1 | longitude: Common.Utils.Math.deg2rad(-120.0005)}
   {dx, dy} = Common.Utils.Location.dx_dy_between_points(wp1, wp2)
   # assert_in_delta(dist, 39.31, dist_range)
   assert_in_delta(dx, 0, dist_range)
   assert_in_delta(dy, -39.31, dist_range)


   # East
   wp4 = %{wp1 | longitude: Common.Utils.Math.deg2rad(-119.9995)}
   {dx, dy} = Common.Utils.Location.dx_dy_between_points(wp1, wp4)
   # assert_in_delta(dist, 39.31, dist_range)
   assert_in_delta(dx, 0, dist_range)
   assert_in_delta(dy, 39.31, dist_range)


   # South
   wp5 = %{wp1 | latitude: Common.Utils.Math.deg2rad(44.99)}
   {dx, dy} = Common.Utils.Location.dx_dy_between_points(wp1, wp5)
   # assert_in_delta(dist, 1112.0, dist_range)
   assert_in_delta(dx, -1112.0, dist_range)
   assert_in_delta(dy, 0, dist_range)


   # North-West
   wp6 = %{wp1 | latitude: Common.Utils.Math.deg2rad(45.001),  longitude: Common.Utils.Math.deg2rad(-120.0015)}
   {dx, dy} = Common.Utils.Location.dx_dy_between_points(wp1, wp6)
   # assert_in_delta(dist, 162.1, dist_range)
   dist = 162.1
   bearing = Common.Utils.Math.deg2rad(313.314167)
   assert_in_delta(dx, dist*:math.cos(bearing), dist_range)
   assert_in_delta(dy, dist*:math.sin(bearing), dist_range)

   # South-East
   wp6 = %{wp1 | latitude: Common.Utils.Math.deg2rad(44.999),  longitude: Common.Utils.Math.deg2rad(-119.9985)}
   {dx, dy} = Common.Utils.Location.dx_dy_between_points(wp1, wp6)
   # assert_in_delta(dist, 162.1, dist_range)
   dist = 162.1
   bearing = Common.Utils.Math.deg2rad(133.313611)
   assert_in_delta(dx, dist*:math.cos(bearing), dist_range)
   assert_in_delta(dy, dist*:math.sin(bearing), dist_range)

  end
end
