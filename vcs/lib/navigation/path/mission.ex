defmodule Navigation.Path.Mission do
  require Logger
  @enforce_keys [:name, :waypoints, :vehicle_turn_rate]

  defstruct [:name, :waypoints, :vehicle_turn_rate]

  @spec new_mission(binary(), list(), atom()) :: struct()
  def new_mission(name, waypoints, vehicle_type) do
    navigation_config_module = Module.concat(Configuration.Vehicle, vehicle_type)
    |> Module.concat(Navigation)
    vehicle_turn_rate =
      apply(navigation_config_module, :get_vehicle_limits,[])
      |> Map.get(:vehicle_turn_rate)
    %Navigation.Path.Mission{
      name: name,
      waypoints: waypoints,
      vehicle_turn_rate: vehicle_turn_rate
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
    Navigation.Path.Mission.new_mission("default", [wp1, wp2, wp3, wp4, wp5], :Plane)
  end

  @spec get_takeoff_waypoints(struct(), float(), atom()) :: list()
  def get_takeoff_waypoints(start_position, course, aircraft_type) do
    takeoff_roll_distance = get_aircraft_spec(aircraft_type, :takeoff_roll)
    climbout_distance = get_aircraft_spec(aircraft_type, :climbout_distance)
    climbout_height = get_aircraft_spec(aircraft_type, :climbout_speed)
    climbout_speed = get_aircraft_spec(aircraft_type, :climbout_speed)
    takeoff_roll = Common.Utils.Location.lla_from_point_with_distance(start_position,takeoff_roll_distance, course)
    climb_position = Common.Utils.Location.lla_from_point_with_distance(start_position,climbout_distance, course)
    |> Map.put(:altitude, start_position.altitude+climbout_height)
    wp0 = Navigation.Path.Waypoint.new_ground(start_position, climbout_speed, course, "WOG")
    wp1 = Navigation.Path.Waypoint.new_climbout(takeoff_roll, climbout_speed, course, "takeoff")
    wp2 = Navigation.Path.Waypoint.new_flight(climb_position, climbout_speed, course, "climbout")
    [wp0, wp1, wp2]
  end

 @spec get_landing_waypoints(struct(), float(), atom()) :: list()
  def get_landing_waypoints(final_position, course, aircraft_type) do
    landing_points = Enum.reduce(get_aircraft_spec(aircraft_type, :landing_distances_heights),[],fn({distance, height},acc) ->
      wp = Common.Utils.Location.lla_from_point_with_distance(final_position, distance, course)
      |> Map.put(:altitude, final_position.altitude+height)
      acc ++ [wp]
    end)
    {approach_speed, touchdown_speed} = get_aircraft_spec(aircraft_type, :landing_speeds)
    wp0 = Navigation.Path.Waypoint.new_flight(Enum.at(landing_points,0), approach_speed, course, "pre-approach")
    wp1 = Navigation.Path.Waypoint.new_approach(Enum.at(landing_points,1), approach_speed, course, "approach")
    wp2 = Navigation.Path.Waypoint.new_landing(Enum.at(landing_points,2), touchdown_speed, course, "flare")
    wp3 = Navigation.Path.Waypoint.new_landing(Enum.at(landing_points,3), 0, course, "WOG")
    [wp0, wp1, wp2, wp3]
  end

  @spec get_complete_mission(binary(), binary(), atom(), atom(), integer()) :: struct()
  def get_complete_mission(airport, runway, aircraft_type, track_type, num_wps) do
    {start_position, start_course} = get_runway_position_heading(airport, runway)
    takeoff_wps = get_takeoff_waypoints(start_position, start_course, aircraft_type)
    first_flight_wp = Enum.at(takeoff_wps, -1)
    flight_wps =
      case track_type do
        nil -> get_random_waypoints(aircraft_type, first_flight_wp, first_flight_wp.speed, first_flight_wp.course,num_wps)
        type -> get_track_waypoints(airport, runway, type, aircraft_type)
      end
    landing_wps = get_landing_waypoints(start_position, start_course, aircraft_type)
    wps = takeoff_wps ++ flight_wps ++ landing_wps
    Enum.each(wps, fn wp ->
      {dx, dy} = Common.Utils.Location.dx_dy_between_points(start_position.latitude, start_position.longitude, wp.latitude, wp.longitude)
      Logger.info("wp: #{wp.name}: (#{Common.Utils.eftb(dx,0)}, #{Common.Utils.eftb(dy,0)}, #{Common.Utils.eftb(wp.altitude,0)})m")
    end)
    Navigation.Path.Mission.new_mission("complete",wps, :Plane)
  end

  @spec get_track_waypoints(atom(), atom(), atom(), atom()) :: list()
  def get_track_waypoints(airport, runway, track_type, aircraft_type) do
    wp_speed =
      case aircraft_type do
        :Cessna -> 45
        :EC1500 -> 15
      end
    wps = %{
      "seatac" =>  %{},
      "montague" =>
      %{
        top_left: {41.7693, -122.5077, 900},
        top_right: {41.7693, -122.50603, 900},
        bottom_left: {41.76782, -122.5077, 900},
        bottom_right: {41.76782, -122.50603, 900}
      }
    }
    wps_and_course_map =
      %{
        "montague" =>
        %{
          "0L" => %{
            racetrack_left: [{:top_left, :math.pi}, {:bottom_left, :math.pi}, {:bottom_right, 0}, {:top_right, 0}],
            racetrack_right: [{:top_right, :math.pi}, {:bottom_right, :math.pi}, {:bottom_left, 0}, {:top_left, 0}],
            hourglass: [{:top_right, :math.pi}, {:bottom_left, :math.pi}, {:bottom_right, 0}, {:top_left, 0}]
          },
          "18R" => %{
            racetrack_left: [{:bottom_right, 0}, {:top_right, 0}, {:top_left, :math.pi}, {:bottom_left, :math.pi}],
            racetrack_right: [{:bottom_left, 0}, {:top_left, 0}, {:top_right, :math.pi}, {:bottom_right, :math.pi}],
            hourglass: [{:bottom_right, 0}, {:top_left, 0}, {:top_right, :math.pi}, {:bottom_left, :math.pi}]
          }
        }
      }
    wps_and_course = get_in(wps_and_course_map, [airport, runway, track_type])
    wps = Enum.reduce(wps_and_course, [], fn ({wp_name, course}, acc) ->
      {lat, lon, alt} = get_in(wps, [airport, wp_name])
      lla = Navigation.Utils.LatLonAlt.new_deg(lat, lon, alt)
      wp = Navigation.Path.Waypoint.new_flight(lla, wp_speed, course,"#{length(acc)+1}")
      acc ++ [wp]
    end)
    wps ++ [Enum.at(wps,0)]
  end

  @spec get_runway_position_heading(binary(), binary()) :: tuple()
  def get_runway_position_heading(airport, runway) do
    {lat, lon, alt, heading} =
      case airport do
      "seatac" ->
        case runway do
          "34R" -> {47.4407476, -122.3180652, 133.3, 0.0}
        end
      "montague" ->
        case runway do
          "0L" -> {41.76816, -122.50686, 802.0, 2.3}
          "18R" -> {41.7689, -122.50682, 803.0, 182.3}
        end
      end
    {Navigation.Utils.LatLonAlt.new_deg(lat, lon, alt), Common.Utils.Math.deg2rad(heading)}
  end


  @spec get_random_waypoints(atom(), struct(), float(), float(), integer(), boolean(), integer()) :: struct()
  def get_random_waypoints(aircraft_type, starting_lla, starting_speed, starting_course, num_wps, loop \\ false, starting_wp_index \\ 0) do
    {min_flight_speed, max_flight_speed} = get_aircraft_spec(aircraft_type, :flight_speed_range)
    {min_flight_agl, max_flight_agl} = get_aircraft_spec(aircraft_type, :flight_agl_range)
    {min_wp_dist, max_wp_dist} = get_aircraft_spec(aircraft_type, :wp_dist_range)
    starting_wp = Navigation.Path.Waypoint.new_flight(starting_lla, starting_speed, starting_course,"wp0")
    flight_speed_range = max_flight_speed - min_flight_speed
    flight_agl_range = max_flight_agl - min_flight_agl
    wp_dist_range = max_wp_dist-min_wp_dist
    wps =
      Enum.reduce(1..num_wps, [starting_wp], fn (index, acc) ->
        last_wp = hd(acc)
        dist = :rand.uniform()*wp_dist_range + min_wp_dist
        bearing = :rand.uniform()*2*:math.pi
        course = :rand.uniform()*2*:math.pi
        speed = :rand.uniform*flight_speed_range + min_flight_speed
        alt = :rand.uniform()*flight_agl_range + min_flight_agl + starting_lla.altitude
        # Logger.info(Navigation.Utils.LatLonAlt.to_string(last_wp))
        # Logger.debug("distance/bearing: #{dist}/#{Common.Utils.Math.rad2deg(bearing)}")
        new_pos = Common.Utils.Location.lla_from_point_with_distance(last_wp, dist, bearing)
        |> Map.put(:altitude, alt)
        new_wp = Navigation.Path.Waypoint.new_flight(new_pos, speed, course, "wp#{index}")
        [new_wp | acc]
      end)
      |> Enum.reverse()
    |> Enum.drop(1)
    Logger.warn("before loop")
    # Enum.each(wps, fn wp ->
    #   Logger.info("wp: #{wp.name}/#{wp.altitude}m")
    # end)
    if loop do
      first_wp = Enum.at(wps,0)
      last_wp = %{first_wp | goto: starting_wp_index}
      wps ++ [last_wp]
    else
      wps
    end
  end

  @spec get_aircraft_spec(atom(), atom()) :: any()
  def get_aircraft_spec(aircraft_type, spec) do
    aircraft = %{
      Cessna: %{
        takeoff_roll: 500,
        climbout_distance: 1200,
        climbout_height: 100,
        climbout_speed: 45,
        landing_distances_heights: [{-1400,100}, {-900,100}, {100,5}, {600,0}],
        landing_speeds: {45, 35},
        flight_speed_range: {35,45},
        flight_agl_range: {300, 400},
        wp_dist_range: {600, 1600},
        planning_turn_rate: 0.08
      },
      EC1500: %{
        takeoff_roll: 30,
        climbout_distance: 200,
        climbout_height: 40,
        climbout_speed: 15,
        landing_distances_heights: [{-250, 40}, {-200,40}, {-50,3}, {1,0}],
        landing_speeds: {15, 10},
        flight_speed_range: {15,20},
        flight_agl_range: {50, 100},
        wp_dist_range: {200, 400},
        planning_turn_rate: 0.80
      }
    }
    get_in(aircraft, [aircraft_type, spec])
  end
end
