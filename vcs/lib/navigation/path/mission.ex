defmodule Navigation.Path.Mission do
  require Logger
  @enforce_keys [:name]

  defstruct [:name, :waypoints, :origin]

  @spec new_mission(binary(), list()) :: struct()
  def new_mission(name, waypoints \\ []) do
    %Navigation.Path.Mission{
      name: name,
      waypoints: waypoints,
      origin: nil
    }
  end

  @spec set_waypoints(struct(), list()) :: struct()
  def set_waypoints(mission, waypoints) do
    %{mission | waypoints: waypoints}
  end

  @spec add_waypoint_at_index(struct(), struct(), integer()) :: struct()
  def add_waypoint_at_index(mission, waypoint, index) do
    waypoints =
    if (index >= -1) do
      List.insert_at(mission.waypoints, index, waypoint)
    else
      Logger.warn("Index cannot be less than -1")
      mission.waypoints
    end
    %{mission | waypoints: waypoints }
  end

  @spec remove_waypoint_at_index(struct(), integer()) :: struct()
  def remove_waypoint_at_index(mission, index) do
    waypoints =
    if (index >= -1) do
      List.delete_at(mission.waypoints, index)
    else
      Logger.warn("Index cannot be less than -1")
      mission.waypoints
    end
    %{mission | waypoints: waypoints }
  end

  @spec remove_all_waypoints(struct()) :: struct()
  def remove_all_waypoints(mission) do
    %{mission | waypoints: []}
  end


  @spec get_default_mission() :: struct()
  def get_default_mission() do
    speed = 2
    alt = 100
    lat1 = Common.Utils.Math.deg2rad(45.00)
    lon1 = Common.Utils.Math.deg2rad(-120.0)

    {lat2, lon2} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 200, 20)
    {lat3, lon3} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 0, 40)
    {lat4, lon4} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 100, 30)
    {lat5, lon5} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 100, -70)

    wp1 = Navigation.Path.Waypoint.new(lat1, lon1, speed, :math.pi/2, alt, "wp1")
    wp2 = Navigation.Path.Waypoint.new(lat2, lon2, speed, :math.pi/2, alt, "wp2")
    wp3 = Navigation.Path.Waypoint.new(lat3, lon3, speed, :math.pi/2, alt, "wp3",2)
    wp4 = Navigation.Path.Waypoint.new(lat4, lon4, speed, :math.pi, alt, "wp4")
    wp5 = Navigation.Path.Waypoint.new(lat5, lon5, speed, 0, alt, "wp5", 0)
    Navigation.Path.Mission.new_mission("default", [wp1, wp2, wp3, wp4, wp5])
  end

  @spec get_seatac_mission() :: struct()
  def get_seatac_mission() do
    speed = 45
    alt = 300
    lat1 = Common.Utils.Math.deg2rad(47.440622)
    lon1 = Common.Utils.Math.deg2rad(-122.318562)
    {lat2, lon2} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 2500, 0)
    {lat3, lon3} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 2500, 1500)
    {lat4, lon4} = Common.Utils.Location.lat_lon_from_point(lat1, lon1, 0, 1500)
    wp1 = Navigation.Path.Waypoint.new(lat1, lon1, speed, 0, alt, "wp1")
    wp2 = Navigation.Path.Waypoint.new(lat2, lon2, speed, 0, alt, "wp2")
    wp3 = Navigation.Path.Waypoint.new(lat3, lon3, speed, :math.pi, alt, "wp3")
    wp4 = Navigation.Path.Waypoint.new(lat4, lon4, speed, :math.pi, alt, "wp4")
    wp5 = Navigation.Path.Waypoint.new(lat1, lon1, speed, 0, alt, "wp5",0)
    Navigation.Path.Mission.new_mission("SeaTac", [wp1, wp2, wp3, wp4, wp5])
  end

  @spec get_random_seatac_mission() :: struct()
  def get_random_seatac_mission() do
    alt = 300
    lat1 = Common.Utils.Math.deg2rad(47.440622)
    lon1 = Common.Utils.Math.deg2rad(-122.318562)
    lla = Navigation.Path.LatLonAlt.new(lat1, lon1, alt)
    num_wps = :rand.uniform(4)# + 4
    loop = if (:rand.uniform(2) == 1), do: true, else: false
    get_random_mission(lla, num_wps, loop)
  end

  @spec get_random_mission(struct(), integer(), boolean()) :: struct()
  def get_random_mission(starting_lla, num_wps, loop) do
    starting_course = :rand.uniform()*2*:math.pi
    max_speed = 55
    min_speed = 45
    starting_speed = :rand.uniform*(max_speed-min_speed) + min_speed
    starting_wp = Navigation.Path.Waypoint.new(
      starting_lla.latitude,
      starting_lla.longitude,
      starting_speed, starting_course,
      starting_lla.altitude,"wp1")
    min_wp_dist = 1000
    wp_dist_range = 1500
    wps =
      Enum.reduce(2..num_wps, [starting_wp], fn (index, acc) ->
        last_wp = hd(acc)
        dist = :rand.uniform()*wp_dist_range + min_wp_dist
        bearing = :rand.uniform()*2*:math.pi
        course = :rand.uniform()*2*:math.pi
        speed = :rand.uniform*(max_speed-min_speed) + min_speed
        Navigation.Path.LatLonAlt.print_deg(last_wp)
        Logger.debug("distance/bearing: #{dist}/#{Common.Utils.Math.rad2deg(bearing)}")
        {lat, lon} = Common.Utils.Location.lat_lon_from_point_with_distance(last_wp, dist, bearing)
        new_wp = Navigation.Path.Waypoint.new(lat, lon, speed, course, starting_lla.altitude, "wp#{index}")
        [new_wp | acc]
      end)
    wps =
    if loop do
      last_wp = %{starting_wp | goto: 0}
      [last_wp | wps]
    else
      wps
    end
    wps = Enum.reverse(wps)
    Navigation.Path.Mission.new_mission("random", wps)
  end
end
