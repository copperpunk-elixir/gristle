defmodule Display.Scenic.Planner do
  use Scenic.Scene
  require Logger

  import Scenic.Primitives

  @primitive_id :mission_primitives

  @moduledoc """
  This version of `Sensor` illustrates using spec functions to
  construct the display graph. Compare this with `Sensor` which uses
  anonymous functions.
  """

  # ============================================================================
  def init(_, opts) do
    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} =
      opts[:viewport]
      |> Scenic.ViewPort.info()
    graph =
      Scenic.Graph.build(font: :roboto, font_size: 16, theme: :dark)
      |> Display.Scenic.Gcs.Utils.draw_arrow(0,0, 0, 1, :vehicle, true, :clear)
    state = %{
      graph: graph,
      width: vp_width,
      height: vp_height,
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :load_mission, self())
    Comms.Operator.join_group(__MODULE__, :pv_estimate, self())
    {:ok, state, push: graph}
  end

  def handle_cast({:load_mission, mission}, state) do
    Logger.warn("planner load mission")
    vehicle_position =
      Map.get(state, :vehicle, %{})
      |> Map.get(:position)
    bounding_box = calculate_lat_lon_bounding_box(mission, vehicle_position)
    origin = calculate_origin(bounding_box, state.width, state.height)
    {config_points, _current_path_distance} = Navigation.PathManager.new_path(mission.waypoints, 0.08)
    graph =
      Scenic.Graph.delete(state.graph, @primitive_id)
      |> draw_waypoints(origin, state.height, mission.waypoints)
      |> draw_path(origin, state.height, config_points)
    state = Map.put(state, :mission, mission)
    |> Map.put(:origin, origin)
    |> Map.put(:graph, graph)
    {:noreply, state, push: graph }
  end

  def handle_cast({:pv_estimate, pv_value_map}, state) do
    position = pv_value_map.position
    yaw = pv_value_map.attitude.yaw
    speed = pv_value_map.speed
    vehicle = %{position: position, yaw: yaw, speed: speed}
    origin =
    if Map.get(state, :origin) == nil do
      bounding_box = calculate_lat_lon_bounding_box(%{}, position)
      calculate_origin(bounding_box, state.width, state.height)
    else
      state.origin
    end
    graph = draw_vehicle(state.graph, vehicle, origin, state.height)
    state =
      Map.put(state, :vehicle, vehicle)
      |> Map.put(:origin, origin)
      |> Map.put(:graph, graph)
    {:noreply, state, push: graph}
  end

  @spec calculate_lat_lon_bounding_box(map(), map(), boolean()) :: tuple()
  def calculate_lat_lon_bounding_box(mission, vehicle_position, degrees \\ false) do
    {min_lat, max_lat, min_lon, max_lon} =
    if degrees==true do
      {90, -90, 180, -180}
    else
      {:math.pi/2, -:math.pi/2, :math.pi, -:math.pi}
    end


    waypoints = Map.get(mission, :waypoints, [])

    all_coords =
    if vehicle_position == nil do
      waypoints
    else
      [vehicle_position] ++ waypoints
    end
    {min_lat, max_lat, min_lon, max_lon} =
      Enum.reduce(all_coords, {min_lat, max_lat, min_lon, max_lon}, fn (coord, acc) ->
        lat = coord.latitude
        lon = coord.longitude
        min_lat = min(elem(acc,0), lat)
        max_lat = max(elem(acc,1), lat)
        min_lon = min(elem(acc,2), lon)
        max_lon = max(elem(acc,3), lon)
        {min_lat, max_lat, min_lon, max_lon}
      end)

    min_separation = 0.001
    {min_lat, max_lat} =
    if min_lat == max_lat do
      dLat = min_separation
      {min_lat-dLat, max_lat+dLat}
    else
      {min_lat, max_lat}
    end

    {min_lon, max_lon} =
    if min_lon == max_lon do
      dLon = min_separation*:math.sqrt(2)
      {min_lon-dLon, max_lon+dLon}
    else
      {min_lon, max_lon}
    end
    # {min_lat, max_lat, min_lon, max_lon}
    {Navigation.Utils.LatLonAlt.new(min_lat, min_lon), Navigation.Utils.LatLonAlt.new(max_lat, max_lon)}
  end

  @spec calculate_origin(tuple(), integer(), integer()) :: tuple()
  def calculate_origin(bounding_box, vp_width, vp_height) do
    # {min_lat, max_lat, min_lon, max_lon} = bounding_box
    {bottom_left, top_right} = bounding_box
    Logger.info("bottom left: #{Navigation.Utils.LatLonAlt.to_string(bottom_left)}")
    Logger.info("top right: #{Navigation.Utils.LatLonAlt.to_string(top_right)}")
    aspect_ratio = vp_width/vp_height
    # dx_dist_from_lat = max_lat-min_lat
    # dy_dist_from_lon = (max_lon-min_lon)/:math.sqrt(2)
    {dx_dist, dy_dist} = Common.Utils.Location.dx_dy_between_points(bottom_left, top_right)
    # Logger.warn("dx_dist/dy_dist: #{dx_dist}/#{dy_dist}")
    gap_x = 1/dx_dist
    gap_y = aspect_ratio/dy_dist
    # Logger.debug("gap_x/gap_y: #{gap_x}/#{gap_y}")
    margin = 0.5
    {origin, total_x, total_y} =
    if (gap_x < gap_y) do
      total_dist_x = (1+2*margin)*dx_dist
      total_dist_y = aspect_ratio*total_dist_x#*:math.sqrt(2)
      margin_x = margin*dx_dist
      margin_y = (total_dist_y - dy_dist)/2
      origin = Common.Utils.Location.lla_from_point(bottom_left, -margin_x, -margin_y)
      top_corner = Common.Utils.Location.lla_from_point(top_right, margin_x, margin_y)
      {total_dist_lat, total_dist_lon} = {top_corner.latitude-origin.latitude, top_corner.longitude-origin.longitude}
      {origin, total_dist_lat, total_dist_lon}
    else
      total_dist_y = (1 + 2*margin) * dy_dist##*:math.sqrt(2)
      total_dist_x = total_dist_y/aspect_ratio
      margin_y = margin*dy_dist
      margin_x = (total_dist_x - dx_dist)/2
      origin = Common.Utils.Location.lla_from_point(bottom_left, -margin_x, -margin_y)
      top_corner = Common.Utils.Location.lla_from_point(top_right, margin_x, margin_y)
      {total_dist_lat, total_dist_lon} = {top_corner.latitude-origin.latitude, top_corner.longitude-origin.longitude}
      {origin, total_dist_lat, total_dist_lon}
    end
    dx_lat = vp_height/total_x
    dy_lon = vp_width/total_y
    # Logger.warn("dx_lat/dy_lon: #{dx_lat}/#{dy_lon}")
    # Logger.warn("dx/dy ratio: #{dx_lat/dy_lon}")
    Display.Scenic.PlannerOrigin.new_origin(origin.latitude, origin.longitude, dx_lat, dy_lon)
  end

  # @spec get_origin_without_mission(float(), float()) :: struct()
  # def get_boundary_without_mission(lat, lon, vp_width, vp_height) do
  #   dLat = 0.001
  #   dLon = dLat*sqrt(2)
  #   bounding_box = {lat - dLat, lat + dLat, lon - dLon, lon + dLon}
  # end

  @spec draw_waypoints(map(), struct(),float(), list()) :: map()
  def draw_waypoints(graph, origin, height, waypoints) do
    Enum.reduce(waypoints, graph, fn (wp, acc) ->
      wp_plot = get_translate(wp, origin, height)
      Logger.info("#{wp.name} xy: #{inspect(wp_plot)}")
      Logger.info(Navigation.Utils.LatLonAlt.to_string(wp))
      circle(acc, 10, fill: :blue, translate: wp_plot, id: @primitive_id)
      |> text(wp.name, translate: wp_plot, id: @primitive_id)
    end)
  end

  @spec draw_path(map(), struct(), float(), list()) :: map()
  def draw_path(graph, origin, height, config_points) do
    line_width = 5
    Enum.reduce(config_points, graph, fn(cp, acc) ->
      #Arc
      # Line
      cs_arc_start_angle =  (Common.Utils.angle_between_points(cp.cs, cp.pos) - :math.pi/2) |> Common.Utils.constrain_angle_to_compass()
      cs_arc_finish_angle = (Common.Utils.angle_between_points(cp.cs, cp.z1) - :math.pi/2) |> Common.Utils.constrain_angle_to_compass()
      {cs_arc_start_angle, cs_arc_finish_angle} = correct_arc_angles(cs_arc_start_angle, cs_arc_finish_angle, cp.start_direction)
      # if (cs_arc_finish_angle - cs_arc_start_angle < ) do
      # end
      ce_arc_start_angle =  Common.Utils.angle_between_points(cp.ce, cp.z2) - :math.pi/2 |> Common.Utils.constrain_angle_to_compass()
      ce_arc_finish_angle = Common.Utils.angle_between_points(cp.ce, cp.z3) - :math.pi/2 |> Common.Utils.constrain_angle_to_compass()
      {ce_arc_start_angle, ce_arc_finish_angle} = correct_arc_angles(ce_arc_start_angle, ce_arc_finish_angle, cp.end_direction)
        # Common.Utils.constrain_angle_to_compass(:math.atan2(cp.q1.y, cp.q1.x) - cp.start_direction*:math.pi/2)
      # Logger.debug("q1: #{inspect(cp.q1)}")
      # Logger.debug("cs start/finish: #{Common.Utils.Math.rad2deg(Common.Utils.constrain_angle_to_compass(cs_arc_start_angle+:math.pi/2))}/#{Common.Utils.Math.rad2deg(Common.Utils.constrain_angle_to_compass(cs_arc_finish_angle+:math.pi/2))}")
      # Logger.debug("ce start/finish: #{Common.Utils.Math.rad2deg(Common.Utils.constrain_angle_to_compass(ce_arc_start_angle+:math.pi/2))}/#{Common.Utils.Math.rad2deg(Common.Utils.constrain_angle_to_compass(ce_arc_finish_angle+:math.pi/2))}")
      # Logger.debug("cs/ce loc:")
      # Navigation.Utils.LatLonAlt.print_deg(cp.cs)
      # Navigation.Utils.LatLonAlt.print_deg(cp.ce)
      radius_cs = Display.Scenic.PlannerOrigin.get_dx_dy(origin, cp.cs, cp.pos) |> Common.Utils.Math.hypot() |> round()
      radius_ce = Display.Scenic.PlannerOrigin.get_dx_dy(origin, cp.ce, cp.z2) |> Common.Utils.Math.hypot() |> round()
      # Logger.debug("radius_cs: #{radius_cs}")
      # Logger.debug("radius_ce: #{radius_ce}")
      # course_line_end = Common.Utils.Location() get_translate()
      line_start = get_translate(cp.z1, origin, height)
      line_end = get_translate(cp.z2, origin, height)
      cs = get_translate(cp.cs, origin, height)
      ce = get_translate(cp.ce, origin, height)
      # z0 = get_translate(cp.pos, origin, height)
      # z1 = get_translate(cp.z1, origin, height)
      # z2 = get_translate(cp.z2, origin, height)
      # z3 = get_translate(cp.ce, origin, height)
      # Logger.debug("wp/z1/z2")
      # Navigation.Utils.LatLonAlt.print_deg(cp.pos, :debug)
      # Navigation.Utils.LatLonAlt.print_deg(cp.z1)
      # Navigation.Utils.LatLonAlt.print_deg(cp.z2)
      line(acc, {line_start, line_end}, stroke: {line_width, :white}, id: @primitive_id)
      # |> line()
      |> circle(3, stroke: {2, :green}, translate: cs , id: @primitive_id)
      |> circle(5, stroke: {2, :red}, translate: ce , id: @primitive_id)
      # |> line({cs, z0}, stroke: {2, :green})
      # |> line({cs, z1}, stroke: {2, :red})
      # |> line({ce, z2}, stroke: {2, :green})
      |> arc({radius_cs, cs_arc_start_angle, cs_arc_finish_angle}, stroke: {line_width, :green}, translate: cs , id: @primitive_id)
      |> arc({radius_ce, ce_arc_start_angle, ce_arc_finish_angle}, stroke: {line_width, :red}, translate: ce , id: @primitive_id)
      #Arc
    end)
  end

  @spec draw_vehicle(map(), struct(), struct(), float()) :: map()
  def draw_vehicle(graph, vehicle, origin, vp_height) do
    {y_plot,x_plot} = Display.Scenic.PlannerOrigin.get_xy(origin, vehicle.position.latitude, vehicle.position.longitude)
    # Logger.debug("xy_plot: #{x_plot}/#{y_plot}")
    vehicle_size = ceil(vehicle.speed/10) + 10
    Display.Scenic.Gcs.Utils.draw_arrow(graph, x_plot, vp_height-y_plot, vehicle.yaw, vehicle_size, :vehicle)
  end

  @spec get_translate(struct(), tuple(), float()) :: tuple()
  def get_translate(point, origin, vp_height) do
    {y, x} = Display.Scenic.PlannerOrigin.get_xy(origin, point.latitude, point.longitude)
    {x, vp_height - y}
  end

  @spec correct_arc_angles(float(), float(), integer()) :: tuple()
  def correct_arc_angles(start, finish, direction) do
    # Logger.debug("start/finish initial: #{Common.Utils.Math.rad2deg(start)}/#{Common.Utils.Math.rad2deg(finish)}")
    arc = Common.Utils.turn_left_or_right_for_correction(start - finish) |> abs()
    if (arc < Common.Utils.Math.deg2rad(2)) do
      {0,0}
    else
      if direction > 0 do
        # Turning right
        if(finish < start) do
          {start, finish+2.0*:math.pi()}
        else
          {start, finish}
        end
      else
        cs_start = finish
        cs_finish = start
        if (cs_finish < cs_start) do
          {cs_start, cs_finish + 2.0*:math.pi()}
        else
          {cs_start, cs_finish}
        end
      end
    end
  end

end
