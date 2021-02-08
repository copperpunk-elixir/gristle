defmodule Navigation.Path.Mission do
  require Logger
  @enforce_keys [:name, :waypoints, :vehicle_turn_rate]

  defstruct [:name, :waypoints, :vehicle_turn_rate]

  @spec new_mission(binary(), list()) :: struct()
  def new_mission(name, waypoints) do
    model_type = Common.Utils.Configuration.get_model_type()
    # vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    # navigation_config_module = Module.concat(Configuration.Vehicle, vehicle_type)
    # |> Module.concat(Navigation)
    # vehicle_turn_rate =
      # apply(navigation_config_module, :get_vehicle_limits,[model_type])
      # |> Keyword.get(:vehicle_turn_rate)
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    new_mission(name, waypoints, planning_turn_rate)
  end

  @spec new_mission(binary(), list(), float()) :: struct()
  def new_mission(name, waypoints, vehicle_turn_rate) do
    %Navigation.Path.Mission{
      name: name,
      waypoints: waypoints,
      vehicle_turn_rate: vehicle_turn_rate
    }
  end

  @spec calculate_orbit_parameters(binary(), float()) :: tuple()
  def calculate_orbit_parameters(model_type, radius) do
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    cruise_speed = get_model_spec(model_type, :cruise_speed)
    min_loiter_speed = get_model_spec(model_type, :min_loiter_speed)
    # Assume right turn if radius = 0
    direction = if radius >= 0, do: 1, else: -1
    radius = abs(radius)
    turn_rate = if radius != 0, do: cruise_speed/radius, else: 0
    # Turn rate , Speed , Radius
    if (turn_rate > planning_turn_rate) or (turn_rate == 0) do
      speed = planning_turn_rate*radius
      # Logger.warn("turn rate too high. new speed: #{speed}")
      cond do
        speed < min_loiter_speed ->
          # Logger.warn("too slow")
          radius = min_loiter_speed/planning_turn_rate
          {planning_turn_rate, min_loiter_speed, radius*direction}
        speed > cruise_speed ->
          # Logger.warn("too fast")
          radius = cruise_speed / planning_turn_rate
          {planning_turn_rate, cruise_speed, radius*direction}
        true ->
          {planning_turn_rate, speed, radius*direction}
      end
    else
      {turn_rate, cruise_speed, radius*direction}
    end
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
      Logger.debug("Index cannot be less than -1")
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
      Logger.debug("Index cannot be less than -1")
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
    latlon1 = Common.Utils.LatLonAlt.new_deg(45.0, -120.0, 100)
    latlon2 = Common.Utils.Location.lla_from_point(latlon1, 200, 20)
    latlon3 = Common.Utils.Location.lla_from_point(latlon1, 0, 40)
    latlon4 = Common.Utils.Location.lla_from_point(latlon1, 100, 30)
    latlon5 = Common.Utils.Location.lla_from_point(latlon1, 100, -70)

    wp1 = Navigation.Path.Waypoint.new_flight(latlon1, speed, :math.pi/2, "wp1")
    wp2 = Navigation.Path.Waypoint.new_flight(latlon2, speed, :math.pi/2, "wp2")
    wp3 = Navigation.Path.Waypoint.new_flight(latlon3, speed, :math.pi/2, "wp3",2)
    wp4 = Navigation.Path.Waypoint.new_flight(latlon4, speed, :math.pi, "wp4")
    wp5 = Navigation.Path.Waypoint.new_flight(latlon5, speed, 0, "wp5", 0)

    model_type = Common.Utils.Configuration.get_model_type()
    # vehicle_turn_rate = Configuration.Vehicle.Plane.Navigation.get_vehicle_limits(model_type)
    # |> Keyword.get(:vehicle_turn_rate)
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    Navigation.Path.Mission.new_mission("default", [wp1, wp2, wp3, wp4, wp5], planning_turn_rate)
  end

  @spec get_takeoff_waypoints(struct(), float(), binary()) :: list()
  def get_takeoff_waypoints(start_position, course, model_type) do
    Logger.debug("start: #{Common.Utils.LatLonAlt.to_string(start_position)}")
    takeoff_roll_distance = get_model_spec(model_type, :takeoff_roll)
    climbout_distance = get_model_spec(model_type, :climbout_distance)
    climbout_height = get_model_spec(model_type, :climbout_height)
    climbout_speed = get_model_spec(model_type, :climbout_speed)
    cruise_speed = get_model_spec(model_type, :cruise_speed)
    takeoff_roll = Common.Utils.Location.lla_from_point_with_distance(start_position,takeoff_roll_distance, course)
    climb_position = Common.Utils.Location.lla_from_point_with_distance(start_position,climbout_distance, course)
    |> Map.put(:altitude, start_position.altitude+climbout_height)
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    case vehicle_type do
      "Plane" ->
        wp0 = Navigation.Path.Waypoint.new_ground(start_position, climbout_speed, course, "Start")
        wp1 = Navigation.Path.Waypoint.new_climbout(takeoff_roll, climbout_speed, course, "takeoff")
        wp2 = Navigation.Path.Waypoint.new_flight(climb_position, cruise_speed, course, "climbout")
        [wp0, wp1, wp2]
      "Multirotor" ->
        # start_position = Common.Utils.Location.lla_from_point_with_distance(start_position,5.0, course+:math.pi)
        start_position = %{start_position | altitude: start_position.altitude + 3.0}
        takeoff_roll = %{takeoff_roll | altitude: takeoff_roll.altitude + 3.0}
        wp0 = Navigation.Path.Waypoint.new_flight(start_position, climbout_speed, course, "Start")
        wp1 = Navigation.Path.Waypoint.new_flight(takeoff_roll, climbout_speed, course, "takeoff")
        wp2 = Navigation.Path.Waypoint.new_flight(climb_position, cruise_speed, course, "climbout")
        [wp0, wp1, wp2]
    end
  end

 @spec get_landing_waypoints(struct(), float(), binary()) :: list()
  def get_landing_waypoints(final_position, course, model_type) do
    landing_points = Enum.reduce(get_model_spec(model_type, :landing_distances_heights),[],fn({distance, height},acc) ->
      wp = Common.Utils.Location.lla_from_point_with_distance(final_position, distance, course)
      |> Map.put(:altitude, final_position.altitude+height)
      acc ++ [wp]
    end)
    {approach_speed, touchdown_speed} = get_model_spec(model_type, :landing_speeds)

    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    case vehicle_type do
      "Plane" ->
        [Navigation.Path.Waypoint.new_approach(Enum.at(landing_points,0), approach_speed, course, "approach")]
        ++ [Navigation.Path.Waypoint.new_landing(Enum.at(landing_points,1), touchdown_speed, course, "flare")]
        ++ [Navigation.Path.Waypoint.new_landing(Enum.at(landing_points,2), touchdown_speed, course, "descent")]
        ++ [Navigation.Path.Waypoint.new_landing(Enum.at(landing_points,3), 0, course, "touchdown")]
      "Multirotor" ->
        cruise_speed = get_model_spec(model_type, :cruise_speed)
        [Navigation.Path.Waypoint.new_flight(Enum.at(landing_points,0), cruise_speed, course, "pre-approach")]
        ++ [Navigation.Path.Waypoint.new_flight(Enum.at(landing_points,1), approach_speed, course, "approach")]
        ++ [Navigation.Path.Waypoint.new_flight(Enum.at(landing_points,2), approach_speed, course, "descent")]
        ++ [Navigation.Path.Waypoint.new_flight(Enum.at(landing_points,3), touchdown_speed, course, "touchdown")]

    end
    # wp0 = Navigation.Path.Waypoint.new_flight(Enum.at(landing_points,0), approach_speed, course, "pre-approach")
    # [wp0, wp1, wp2, wp3, wp4]
  end

  @spec get_complete_mission(binary(), binary(), binary(), binary(), integer(), struct(), struct()) :: struct()
  def get_complete_mission(airport, runway, model_type, track_type, num_wps, start_position \\ nil, start_course \\ nil) do
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    {start_position, start_course} =
    if is_nil(start_position) or is_nil(start_course) do
      get_runway_position_heading(airport, runway)
    else
      {start_position, start_course}
    end
    takeoff_wps = get_takeoff_waypoints(start_position, start_course, model_type)
    starting_wp = Enum.at(takeoff_wps, 0)
    first_flight_wp = Enum.at(takeoff_wps, -1)
    flight_wps =
      case track_type do
        "none" ->
          if num_wps > 0 do
            get_random_waypoints(model_type, starting_wp, first_flight_wp,num_wps)
          else
            course = first_flight_wp.course
            speed = first_flight_wp.speed
            pos = Common.Utils.LatLonAlt.new(first_flight_wp.latitude, first_flight_wp.longitude, first_flight_wp.altitude+0*30)
            distance = 2*speed / planning_turn_rate
            new_course = Common.Utils.Motion.constrain_angle_to_compass(course + :math.pi)
            new_pos_temp = Common.Utils.Location.lla_from_point_with_distance(pos, distance, course - :math.pi/2)
            new_pos = Common.Utils.Location.lla_from_point_with_distance(new_pos_temp, 50, new_course)
            new_wp = Navigation.Path.Waypoint.new_flight_peripheral(new_pos, speed, new_course, "wp1")
            [new_wp]
          end
        type -> get_track_waypoints(airport, runway, type, model_type, true)
      end
    landing_wps = get_landing_waypoints(start_position, start_course, model_type)
    # Logger.debug(inspect(landing_wps))
    wps = takeoff_wps ++ flight_wps ++ landing_wps
    print_waypoints_relative(start_position, wps)
    Navigation.Path.Mission.new_mission("#{airport} - #{runway}: #{track_type}",wps, planning_turn_rate)
  end

  @spec get_flight_mission(binary(), binary(), binary(), binary()) :: struct()
  def get_flight_mission(airport, runway, model_type, track_type) do
    wps = get_track_waypoints(airport, runway, track_type, model_type, true)
    print_waypoints_relative(Enum.at(wps, 0), wps)
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    Navigation.Path.Mission.new_mission("#{airport} - #{runway}: #{track_type}",wps, planning_turn_rate)
  end


  @spec get_landing_mission(binary(), binary(), binary()) :: struct()
  def get_landing_mission(airport, runway, model_type) do
    {start_position, start_course} = get_runway_position_heading(airport, runway)
    wps = get_landing_waypoints(start_position, start_course, model_type)
    print_waypoints_relative(start_position, wps)
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    Navigation.Path.Mission.new_mission("#{airport} - #{runway}: landing",wps, planning_turn_rate)
  end

  @spec add_current_position_to_mission(struct(), struct(), float(), float()) :: struct()
  def add_current_position_to_mission(mission, current_position, speed, course) do
    Logger.debug("add current position to mission")
    current_wp = Navigation.Path.Waypoint.new_flight(current_position, speed, course,"start")
    Logger.debug("mission wps:")
    Enum.each(mission.waypoints, fn wp ->
      Logger.debug(Navigation.Path.Waypoint.to_string(wp))
    end)
    Logger.debug("current wp: ")

    Logger.debug(Navigation.Path.Waypoint.to_string(current_wp))
    wps = [current_wp] ++ mission.waypoints
    Navigation.Path.Mission.new_mission(mission.name,wps, mission.vehicle_turn_rate)
  end

  @spec get_track_waypoints(binary(), binary(), atom(), binary(), boolean()) :: list()
  def get_track_waypoints(airport, runway, track_type, model_type, loop) do
    wp_speed = get_model_spec(model_type, :cruise_speed)
    {origin, _runway_heading} = get_runway_position_heading(airport, runway)

    wps_relative = %{
      "flight_school" =>
      %{
        "top_left" => {75,-150,30},
        "top_right" => {75, 50, 30},
        "bottom_left" => {-175, -150, 30},
        "bottom_right" => {-175, 50, 30}
        }
    }

    wps_and_course_map = %{
      "racetrack_left" => [{"top_left", 180}, {"bottom_left", 180}, {"bottom_right", 0}, {"top_right", 0}],
      "racetrack_right" => [{"bottom_left", 0}, {"top_left", 0}, {"top_right", 180}, {"bottom_right", 180}],
      "hourglass_right" => [{"top_left", 0}, {"top_right", 180}, {"bottom_left", 180}, {"bottom_right", 0}],
      "hourglass_left" => [{"top_left", 180}, {"bottom_right", 180}, {"bottom_left", 0}, {"top_right", 0} ]
    }

    reference_headings = %{
      "flight_school" => 180
    }

    wps_and_course = Map.get(wps_and_course_map, track_type)
    reference_heading = Map.get(reference_headings, airport) |> Common.Utils.Math.deg2rad()
    # Logger.debug("origin: #{Common.Utils.LatLonAlt.to_string(origin)}")
    # Logger.debug("reference_heading: #{reference_heading}")
    wps = Enum.reduce(wps_and_course, [], fn ({wp_name, rel_course}, acc) ->
      Logger.debug("#{airport}/#{wp_name}")
      {rel_x, rel_y, rel_alt} = get_in(wps_relative, [airport, wp_name])
      {dx, dy} = Common.Utils.Math.rotate_point(rel_x, rel_y, reference_heading)
      # Logger.warn("relx/rely: #{rel_x}/#{rel_y}")
      # Logger.warn("dx/dy: #{dx}/#{dy}")
      lla = Common.Utils.Location.lla_from_point(origin, dx, dy)
      |> Map.put(:altitude, origin.altitude+rel_alt)
      # lla = Common.Utils.LatLonAlt.new_deg(lat, lon, alt)
      course = Common.Utils.Motion.constrain_angle_to_compass(Common.Utils.Math.deg2rad(rel_course) + reference_heading)
      wp = Navigation.Path.Waypoint.new_flight_peripheral(lla, wp_speed, course,"#{length(acc)+1}")
      acc ++ [wp]
    end)
    first_wp = Enum.at(wps, 0)
    final_wp =
    if loop do
      %{first_wp | goto: first_wp.name}
    else
      first_wp
    end
    wps ++ [final_wp]
  end

  @spec get_lawnmower_mission(binary(), binary(), binary(), integer(), float(), float()) :: struct()
  def get_lawnmower_mission(airport, runway, model_type, num_rows, row_width, row_length) do
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    wps = get_lawnmower_waypoints(airport, runway, model_type, num_rows, row_width, row_length)
    Navigation.Path.Mission.new_mission("#{airport} - #{runway}: lawnmower",wps, planning_turn_rate)
  end

  @spec get_lawnmower_waypoints(binary(), binary(), binary(), integer(), float(), float()) :: list()
  def get_lawnmower_waypoints(airport, runway, model_type, num_rows, row_width, row_length) do
    wp_speed = get_model_spec(model_type, :cruise_speed)
    planning_turn_rate = get_model_spec(model_type, :planning_turn_rate)
    radius = wp_speed/planning_turn_rate
    # Logger.info("radius: #{radius}")
    {origin, _runway_heading} = get_runway_position_heading(airport, runway)
    reference_headings = %{
      "cone_field" => 0
    }

    reference_heading = Map.get(reference_headings, airport) |> Common.Utils.Math.deg2rad()

    {_, wps} =
      Enum.reduce(0..num_rows-1, {reference_heading, []}, fn (row, {current_heading, acc}) ->
        Logger.debug("row/course: #{row}/#{Common.Utils.eftb_deg(current_heading,1)}")
        rel_y = (row*row_width)*:math.sin(reference_heading + :math.pi/2)
        rel_x1 = if (rem(row,2) == 1), do: row_length, else: 0.0
        rel_x2 = rel_x1 + (row_length+1.5*radius)*:math.cos(current_heading)
        {dx1, dy1} =  Common.Utils.Math.rotate_point(rel_x1, rel_y, reference_heading)
        # {rel_x, rel_y, rel_alt} = get_in(wps_relative, [airport, wp_name])
        {dx2, dy2} = Common.Utils.Math.rotate_point(rel_x2, rel_y, reference_heading)
        # Logger.warn("relx/rely: #{rel_x}/#{rel_y}")
        # Logger.debug("dx1/dy1: #{dx1}/#{dy1}")
        # Logger.debug("dx2/dy2: #{dx2}/#{dy2}")
        lla_1 = Common.Utils.Location.lla_from_point(origin, dx1, dy1)
        |> Map.put(:altitude, origin.altitude)
        lla_2 = Common.Utils.Location.lla_from_point(origin, dx2, dy2)
        |> Map.put(:altitude, origin.altitude)

        # lla = Common.Utils.LatLonAlt.new_deg(lat, lon, alt)
        # course = Common.Utils.Motion.constrain_angle_to_compass(current_heading + reference_heading)
        wp1 = Navigation.Path.Waypoint.new_ground_peripheral(lla_1, wp_speed, current_heading,"#{length(acc)+1}")
        wp2 = Navigation.Path.Waypoint.new_ground_peripheral(lla_2, wp_speed, current_heading,"#{length(acc)+2}")
        new_heading = Common.Utils.Motion.constrain_angle_to_compass(current_heading + :math.pi)
        {new_heading, acc ++ [wp1, wp2]}
      end)
    first_wp = Enum.at(wps, 0)
    final_wp = %{first_wp | name: "end", goto: first_wp.name}
    wps ++ [final_wp]
  end

  @spec get_runway_position_heading(binary(), binary()) :: tuple()
  def get_runway_position_heading(airport, runway) do
    origin_heading = %{
      "seatac" => %{
        "34L" => {Common.Utils.LatLonAlt.new_deg(47.4407476, -122.3180652, 133.3), 0.0}
      },
      "montague" => %{
        "36L" => {Common.Utils.LatLonAlt.new_deg(41.76816, -122.50686, 802.0), 2.3},
        "18R" => {Common.Utils.LatLonAlt.new_deg(41.7689, -122.50682, 803.0), 182.3}
      },
      "flight_school" => %{
        "9L" => {Common.Utils.LatLonAlt.new_deg(41.76157, -122.48929, 1186.51), 180.0},
        "18L" => {Common.Utils.LatLonAlt.new_deg(41.76174, -122.48928, 1186.6), 180.0},
        "36R" => {Common.Utils.LatLonAlt.new_deg(41.76105, -122.48928, 1186.7), 0.0},
      },
      "boneyard" => %{
        "36R" => {Common.Utils.LatLonAlt.new_deg(42.18878, -122.08890, 0.2), 358.32}
      },
      "obstacle_course" => %{
        "36R" => {Common.Utils.LatLonAlt.new_deg(41.70676, -122.39755, 1800.4), 0.0}
      },
      "fpv_racing" => %{
        "27R" => {Common.Utils.LatLonAlt.new_deg(41.76302, -122.48963, 1186.6), 270}
      },
      "cone_field" => %{
        "18R" => {Common.Utils.LatLonAlt.new_deg(42.0, -120.0, 0.0), 180.0},
        "36L" => {Common.Utils.LatLonAlt.new_deg(41.76129, -122.49024, 1188.31), 0.0}
      }
    }
    {origin, heading} = get_in(origin_heading, [airport, runway])
    {origin, Common.Utils.Math.deg2rad(heading)}
  end

  @spec get_random_waypoints(binary(), struct(), struct(), integer(), boolean()) :: struct()
  def get_random_waypoints(model_type, ground_wp, first_flight_wp, num_wps, loop \\ false) do
    {min_flight_speed, max_flight_speed} = get_model_spec(model_type, :flight_speed_range)
    {min_flight_agl, max_flight_agl} = get_model_spec(model_type, :flight_agl_range)
    {min_wp_dist, max_wp_dist} = get_model_spec(model_type, :wp_dist_range)
    starting_wp = Navigation.Path.Waypoint.new_flight(first_flight_wp, first_flight_wp.speed, first_flight_wp.course,"wp0")
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
        alt = :rand.uniform()*flight_agl_range + min_flight_agl + ground_wp.altitude
        # Logger.debug(Common.Utils.LatLonAlt.to_string(last_wp))
        # Logger.debug("distance/bearing: #{dist}/#{Common.Utils.Math.rad2deg(bearing)}")
        new_pos = Common.Utils.Location.lla_from_point_with_distance(last_wp, dist, bearing)
        |> Map.put(:altitude, alt)
        new_wp = Navigation.Path.Waypoint.new_flight_peripheral(new_pos, speed, course, "wp#{index}")
        [new_wp | acc]
      end)
      |> Enum.reverse()
    |> Enum.drop(1)
    Logger.debug("before loop")
    # Enum.each(wps, fn wp ->
    #   Logger.debug("wp: #{wp.name}/#{wp.altitude}m")
    # end)
    if loop do
      first_wp = Enum.at(wps,0)
      last_wp = %{first_wp | goto: starting_wp.name}
      wps ++ [last_wp]
    else
      wps
    end
  end

  @spec get_model_spec(binary(), atom()) :: any()
  def get_model_spec(model_type, spec) do
    model = %{
      "Cessna" => %{
        takeoff_roll: 500,
        climbout_distance: 1200,
        climbout_height: 100,
        climbout_speed: 40,
        cruise_speed: 45,
        landing_distances_heights: [{-1400,100}, {-900,100}, {100,5}, {600,0}],
        landing_speeds: {45, 35},
        flight_speed_range: {35,45},
        flight_agl_range: {100, 200},
        wp_dist_range: {600, 1600},
        planning_turn_rate: 0.08
      },
      "CessnaZ2m" => %{
        takeoff_roll: 10,
        climbout_distance: 150,
        climbout_height: 30,
        climbout_speed: 12,
        cruise_speed: 14,
        min_loiter_speed: 12,
        landing_distances_heights: [{-150, 30}, {-10,3}, {20, 1.5}, {50,0}],
        landing_speeds: {13, 10},
        flight_speed_range: {12,18},
        flight_agl_range: {50, 60},
        wp_dist_range: {100, 200},
        planning_turn_rate: 0.20,
        planning_orbit_radius: 30
      },
      "T28" => %{
        takeoff_roll: 30,
        climbout_distance: 200,
        climbout_height: 40,
        climbout_speed: 15,
        cruise_speed: 14,
        min_loiter_speed: 12,
        landing_distances_heights: [{-250, 40}, {-200,40}, {-50,3}, {1,0}],
        landing_speeds: {15, 10},
        flight_speed_range: {15,20},
        flight_agl_range: {50, 100},
        wp_dist_range: {200, 400},
        planning_turn_rate: 0.30,
        planning_orbit_radius: 25
      },
      "T28Z2m" => %{
        takeoff_roll: 30,
        climbout_distance: 200,
        climbout_height: 40,
        climbout_speed: 15,
        cruise_speed: 20,
        landing_distances_heights: [{-250, 40}, {-200,40}, {-50,3}, {1,0}],
        landing_speeds: {15, 10},
        flight_speed_range: {15,20},
        flight_agl_range: {50, 100},
        wp_dist_range: {200, 400},
        planning_turn_rate: 0.80
      },
      "QuadX" => %{
        takeoff_roll: 5,
        climbout_distance: 25,
        climbout_height: 10,
        climbout_speed: 2,
        cruise_speed: 5,
        min_loiter_speed: 5,
        landing_distances_heights: [{-50, 7}, {-30, 5}, {-10, 1}, {0,0.0}],
        landing_speeds: {3, 1.5},
        flight_speed_range: {5,5},
        flight_agl_range: {5, 5},
        wp_dist_range: {100, 100},
        planning_turn_rate: 0.25,
        planning_orbit_radius: 10
      },
      "FerrariF1" => %{
        cruise_speed: 3,
        flight_speed_range: {3,3},
        wp_dist_range: {100, 100},
        planning_turn_rate: 0.5,
        planning_orbit_radius: 20
      }

    }
    get_in(model, [model_type, spec])
  end

  @spec encode(struct(), boolean(), boolean()) :: binary()
  def encode(mission, confirm \\ false, display \\ false) do
    wps = Enum.reduce(mission.waypoints, [], fn (wp, acc) ->
      goto= if (wp.goto == ""), do: nil, else: wp.goto
      wp_proto = Navigation.Path.Protobuf.Mission.Waypoint.new([
      name: wp.name,
      latitude: wp.latitude,
      longitude: wp.longitude,
      altitude: wp.altitude,
      speed: wp.speed,
      course: wp.course,
      goto: goto,
      type: to_string(wp.type) |> String.upcase() |> String.to_atom(),
      peripheral_control_allowed: wp.peripheral_control_allowed
      ])
      acc ++ [wp_proto]
    end)
    mission_proto = Navigation.Path.Protobuf.Mission.new([
      name: mission.name,
      vehicle_turn_rate: mission.vehicle_turn_rate,
      waypoints: wps,
      confirm: confirm,
      display: display
    ])
    Navigation.Path.Protobuf.Mission.encode(mission_proto)
  end

  @spec print_waypoints_relative(struct(), list()) :: atom()
  def print_waypoints_relative(start_position, wps) do
    Enum.each(wps, fn wp ->
      {dx, dy} = Common.Utils.Location.dx_dy_between_points(start_position.latitude, start_position.longitude, wp.latitude, wp.longitude)
      Logger.debug("wp: #{wp.name}: (#{Common.Utils.eftb(dx,0)}, #{Common.Utils.eftb(dy,0)}, #{Common.Utils.eftb(wp.altitude,0)})m")
    end)
  end
end
