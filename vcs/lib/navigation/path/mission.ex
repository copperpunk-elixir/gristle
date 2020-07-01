defmodule Navigation.Path.Mission do
  require Logger
  @enforce_keys [:name, :waypoints]

  defstruct [:name, :waypoints]

  @spec new_mission(binary(), list()) :: struct()
  def new_mission(name, waypoints \\ []) do
    %Navigation.Path.Mission{
      name: name,
      waypoints: waypoints,
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
    speed = 0.8
    latlon1 = Navigation.Utils.LatLonAlt.new_deg(45.0, -120.0, 100)
    latlon2 = Common.Utils.Location.lla_from_point(latlon1, 200, 20)
    latlon3 = Common.Utils.Location.lla_from_point(latlon1, 0, 40)
    latlon4 = Common.Utils.Location.lla_from_point(latlon1, 100, 30)
    latlon5 = Common.Utils.Location.lla_from_point(latlon1, 100, -70)

    wp1 = Navigation.Path.Waypoint.new_flight(latlon1, speed, :math.pi/2, "wp1")
    wp2 = Navigation.Path.Waypoint.new_flight(latlon2, speed, :math.pi/2, "wp2")
    wp3 = Navigation.Path.Waypoint.new_flight(latlon3, speed, :math.pi/2, "wp3",2)
    wp4 = Navigation.Path.Waypoint.new_flight(latlon4, speed, :math.pi, "wp4")
    wp5 = Navigation.Path.Waypoint.new_flight(latlon5, speed, 0, "wp5", 0)
    Navigation.Path.Mission.new_mission("default", [wp1, wp2, wp3, wp4, wp5])
  end

  @spec get_seatac_location() :: struct()
  def get_seatac_location() do
    get_seatac_location(133.3)
  end

  @spec get_seatac_location(number()) :: struct()
  def get_seatac_location(altitude) do
    Navigation.Utils.LatLonAlt.new(Common.Utils.Math.deg2rad(47.4407476), Common.Utils.Math.deg2rad(-122.3180652), altitude)
  end

  @spec get_seatac_mission() :: struct()
  def get_seatac_mission() do
    speed = 45
    latlon1 = get_seatac_location(300)
    latlon2 = Common.Utils.Location.lla_from_point(latlon1, 2500, 0)
    latlon3 = Common.Utils.Location.lla_from_point(latlon1, 2500, 1500)
    latlon4 = Common.Utils.Location.lla_from_point(latlon1, 0, 1500)
    wp1 = Navigation.Path.Waypoint.new_flight(latlon1, speed, 0, "wp1")
    wp2 = Navigation.Path.Waypoint.new_flight(latlon2, speed, 0, "wp2")
    wp3 = Navigation.Path.Waypoint.new_flight(latlon3, speed, :math.pi, "wp3")
    wp4 = Navigation.Path.Waypoint.new_flight(latlon4, speed, :math.pi, "wp4")
    wp5 = Navigation.Path.Waypoint.new_flight(latlon1, speed, 0, "wp5",0)
    Navigation.Path.Mission.new_mission("SeaTac", [wp1, wp2, wp3, wp4, wp5])
  end

  @spec get_random_seatac_mission() :: struct()
  def get_random_seatac_mission() do
    start_position = get_seatac_location(300)
    num_wps = :rand.uniform(4) + 4
    loop = if (:rand.uniform(2) == 1), do: true, else: false
    starting_speed = :rand.uniform*(15) + 40
    starting_course = :rand.uniform()*2*:math.pi
    get_random_mission(start_position, starting_speed, starting_course, num_wps, loop)
  end

  @spec get_ground_mission() :: struct()
  def get_ground_mission() do
    start_position = get_seatac_location()
    takeoff = Common.Utils.Location.lla_from_point(start_position,1500, 0)
    |> Map.put(:altitude, 233.3)
    speed = 45
    course = 0
    wp1 = Navigation.Path.Waypoint.new_ground(start_position, speed, course, "wp1")
    wp2 = Navigation.Path.Waypoint.new_ground(takeoff, speed, course, "wp2")
    Logger.debug("wp1: #{inspect(wp1)}")
    Logger.debug("wp2: #{inspect(wp2)}")
    Navigation.Path.Mission.new_mission("ground",[wp1, wp2])
  end

  @spec get_landing_mission() :: struct()
  def get_landing_mission() do
    start_position = get_seatac_location(233.3)
    touchdown = Common.Utils.Location.lla_from_point(start_position, 1000, 0)
    |> Map.put(:altitude, 133.3)
    stop = Common.Utils.Location.lla_from_point(touchdown, 200, 0)
    approach_speed = 45
    touchdown_speed = 35
    course = 0
    wp1 = Navigation.Path.Waypoint.new_landing(start_position, approach_speed, course, "wp1")
    wp2 = Navigation.Path.Waypoint.new_landing(touchdown, touchdown_speed, course, "wp2")
    wp3 = Navigation.Path.Waypoint.new_landing(stop, 0, course, "wp3")
    Logger.debug("wp1: #{inspect(wp1)}")
    Logger.debug("wp2: #{inspect(wp2)}")
    Logger.debug("wp3: #{inspect(wp2)}")
    Navigation.Path.Mission.new_mission("landing",[wp1, wp2, wp3])
  end

  @spec get_random_takeoff_mission() :: struct()
  def get_random_takeoff_mission() do
    start_position = get_seatac_location(133.3)
    takeoff = Common.Utils.Location.lla_from_point(start_position,1500, 0)
    |> Map.put(:altitude, 233.3)
    speed = 45
    course = 0
    wp1 = Navigation.Path.Waypoint.new_ground(start_position, speed, course, "start")
    wp2 = Navigation.Path.Waypoint.new_ground(takeoff, speed, course, "climbout")
    takeoff_wps = [wp1, wp2]
    Logger.debug("start: #{inspect(wp1)}")
    Logger.debug("climbout: #{inspect(wp2)}")
    flight_wps = get_random_waypoints(wp2, speed, course, 4, true, length(takeoff_wps))
    wps = takeoff_wps ++ flight_wps
    Navigation.Path.Mission.new_mission("takeoff",wps)
  end

  @spec get_random_waypoints(struct(), float(), float(), integer(), boolean()) :: struct()
  def get_random_waypoints(starting_lla, starting_speed, starting_course, num_wps, loop \\ false, starting_wp_index \\ 0) do
    max_speed = 55
    min_speed = 40
    min_alt = 300
    max_alt = 400
    starting_wp = Navigation.Path.Waypoint.new_flight(starting_lla, starting_speed, starting_course,"wp1")
    min_wp_dist = 1000
    wp_dist_range = 1500
    wps =
      Enum.reduce(2..num_wps, [starting_wp], fn (index, acc) ->
        last_wp = hd(acc)
        dist = :rand.uniform()*wp_dist_range + min_wp_dist
        bearing = :rand.uniform()*2*:math.pi
        course = :rand.uniform()*2*:math.pi
        speed = :rand.uniform*(max_speed-min_speed) + min_speed
        alt = :rand.uniform()*(max_alt - min_alt) + min_alt
        Logger.info(Navigation.Utils.LatLonAlt.to_string(last_wp))
        Logger.debug("distance/bearing: #{dist}/#{Common.Utils.Math.rad2deg(bearing)}")
        new_pos = Common.Utils.Location.lla_from_point_with_distance(last_wp, dist, bearing)
        |> Map.put(:altitude, alt)
        new_wp = Navigation.Path.Waypoint.new_flight(new_pos, speed, course, "wp#{index}")
        [new_wp | acc]
      end)
    wps =
    if loop do
      last_wp = %{starting_wp | goto: starting_wp_index}
      [last_wp | wps]
    else
      wps
    end
    Enum.reverse(wps)
  end

  @spec get_random_mission(struct(), float(), float(), integer(), boolean()) :: struct()
  def get_random_mission(starting_lla, starting_speed, starting_course, num_wps, loop) do
    wps = get_random_waypoints(starting_lla, starting_speed, starting_course, num_wps, loop)
    Navigation.Path.Mission.new_mission("random", wps)
  end
end
