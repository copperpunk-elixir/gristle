defmodule Display.Scenic.Planner do
  use Scenic.Scene
  require Logger

  import Scenic.Primitives
  # @body_offset 80
  @font_size 24
  @degrees "°"
  @radians "rads"
  @dps "°/s"
  @radpersec "rps"
  @meters "m"
  @mps "m/s"
  @pct "%"

  # @offset_x 0
  # @width 300
  # @height 50
  # @labels {"", "", ""}
  @rect_border 6

  @moduledoc """
  This version of `Sensor` illustrates using spec functions to
  construct the display graph. Compare this with `Sensor` which uses
  anonymous functions.
  """

  # ============================================================================
  def init(_, opts) do
    Logger.debug("Sensor.init: #{inspect(opts)}")
    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} =
      opts[:viewport]
      |> Scenic.ViewPort.info()
    graph =
      Scenic.Graph.build(font: :roboto, font_size: 16, theme: :dark)
    state = %{
      graph: graph,
      width: vp_width,
      height: vp_height,
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :add_mission, self())
    Comms.Operator.join_group(__MODULE__, :pv_estimate, self())
    {:ok, state, push: graph}
  end

  def handle_cast({:add_mission, mission}, state) do
    Logger.info("state: #{inspect(state)}")
    vehicle_position =
      Map.get(state, :vehicle, %{})
      |> Map.get(:position)
    bounding_box = calculate_lat_lon_bounding_box(mission, vehicle_position, true)
    origin = calculate_origin_and_pixel_ratio(bounding_box, state.width, state.height)
    Logger.debug("bounding box: #{inspect(bounding_box)}")
    graph = draw_waypoints(state.graph, origin, mission.waypoints)
    state = Map.put(state, :mission, mission)
    |> Map.put(:origin, origin)
    {:noreply, state, push: graph }
  end

  def handle_cast({:pv_estimate, pv_value_map}, state) do
    position = pv_value_map.position
    yaw = pv_value_map.attitude.yaw
    speed = pv_value_map.calculated.speed
    vehicle = %{position: position, yaw: yaw, speed: speed}
    graph = state.graph
    {:noreply, Map.put(state, :vehicle, vehicle), push: graph}
  end

  @spec calculate_lat_lon_bounding_box(map(), map(), boolean()) :: tuple()
  def calculate_lat_lon_bounding_box(mission, vehicle_position, degrees \\ false) do
    {min_lat, max_lat, min_lon, max_lon} =
    if degrees==true do
      {90, -90, 180, -180}
    else
      {:math.pi/2, -:math.pi/2, :math.pi, -:math.pi}
    end

    all_coords =
    if vehicle_position == nil do
      mission.waypoints
    else
      [vehicle_position] ++ mission.waypoints
    end
    Enum.reduce(all_coords, {min_lat, max_lat, min_lon, max_lon}, fn (coord, acc) ->
      lat = coord.latitude
      lon = coord.longitude
      min_lat = min(elem(acc,0), lat)
      max_lat = max(elem(acc,1), lat)
      min_lon = min(elem(acc,2), lon)
      max_lon = max(elem(acc,3), lon)
      {min_lat, max_lat, min_lon, max_lon}
    end)
  end

  @spec calculate_origin_and_pixel_ratio(tuple(), integer(), integer()) :: tuple()
  def calculate_origin_and_pixel_ratio(bounding_box, vp_width, vp_height) do
    {min_lat, max_lat, min_lon, max_lon} = bounding_box
    # min_lat = Common.Utils.Math.deg2rad(min_lat)
    # min_lon = Common.Utils.Math.deg2rad(min_lon)
    # max_lat = Common.Utils.Math.deg2rad(max_lat)
    # max_lon = Common.Utils.Math.deg2rad(max_lon)
    # bottom_left = Navigation.Waypoint.new_waypoint(min_lat, min_lon,0,0,0)
    # top_right = Navigation.Waypoint.new_waypoint(max_lat, max_lon,0,0,0)
    # {dx, dy, _distance} = Common.Utils.Location.calculate_rhumb_line_between_waypoints(bottom_left, top_right)
    # larger_dim = max(dx, dy)
    # Logger.info("dx/dy: #{dx}/#{dy}")
    # margin = 0.1*larger_dim
    aspect_ratio = vp_width/vp_height
    Logger.info("ar: w/h: #{aspect_ratio}/#{vp_width}/#{vp_height}")
    dx_dist_from_lat = max_lat-min_lat
    dy_dist_from_lon = (max_lon-min_lon)/:math.sqrt(2)
    Logger.info("dxlat/dylon: #{dx_dist_from_lat}/#{dy_dist_from_lon}")
    gap_x = 1/dx_dist_from_lat
    gap_y = aspect_ratio/dy_dist_from_lon
    Logger.info("gap x/y: #{gap_x}/#{gap_y}")
    margin = 0.2
    {origin_lat, origin_lon, total_x, total_y} =
    if (gap_x < gap_y) do
      Logger.warn("larger gap along horizontal")
      total_dist_x = (1+2*margin)*dx_dist_from_lat
      origin_x = min_lat - margin*dx_dist_from_lat
      total_dist_y = aspect_ratio*total_dist_x*:math.sqrt(2)
      Logger.info("total x/y: #{total_dist_x}/#{total_dist_y}")
      margin_y = (total_dist_y - dy_dist_from_lon*:math.sqrt(2))/2
      Logger.info("margin y: #{margin_y}")
      origin_y = min_lon - margin_y
      {origin_x, origin_y, total_dist_x, total_dist_y}
    else
      Logger.warn("larger gap along vertical")
      total_dist_y = (1+2*margin)*dy_dist_from_lon*:math.sqrt(2)
      origin_y = min_lon - margin*dy_dist_from_lon*:math.sqrt(2)
      total_dist_x = total_dist_y/aspect_ratio
      Logger.info("total x/y: #{total_dist_x}/#{total_dist_y}")
      margin_x = (total_dist_x - dx_dist_from_lat)/2
      Logger.info("margin x: #{margin_x}")
      origin_x = min_lat - margin_x
      Logger.info("max y: #{origin_y + total_dist_y}")
      {origin_x, origin_y, total_dist_x, total_dist_y}
    end
    # margin_pct = 0.1
    # {origin_lat,origin_lon, delta} =
    # if (dx_from_lat > dy_from_lon) do
    #   margin= margin_pct*dx_from_lat
    #   {min_lat - margin, min_lon - (margin +(dx_from_lat-dy_from_lon)/2)*:math.sqrt(2), 2*margin+dx_from_lat}
    # else
    #   margin = margin_pct*dy_from_lon
    #   {min_lat - (margin + (dy_from_lon-dx_from_lat)/2)/:math.sqrt(2), min_lon - margin, 2*margin+dy_from_lon}
    # end
    Logger.info("origin lat/lon: #{origin_lat}/#{origin_lon}")
    # {cx, cy} = {min_lat + dlat/2, min_lon + dlon/2}
    # larger_dim = max(dlat/aspect_ratio, dlon)
    # margin = larger_dim * 0.1
    # delta = larger_dim + margin*2
    # origin_lat = cx - delta/2
    # origin_lon = cy - delta/2


    # aspect_ratio = vp_width/vp_height
    # {min_lat, max_lat, min_lon, max_lon} = bounding_box
    # dlat = (max_lat-min_lat)*:math.sqrt(2)
    # dlon = (max_lon-min_lon)#*:math.sqrt(2)
    # larger_dim = max(dlat, dlon)
    # Logger.info("larger: #{larger_dim}")
    # margin = larger_dim * 0.1
    # delta = larger_dim + margin*2
    # {cx, cy} = {min_lat + larger_dim/2, min_lon + larger_dim/2}
    # Logger.info("center: #{cx}/#{cy}")
    # origin_lat = cx - delta/2
    # origin_lon = cy - delta/2
    # margin_lat = 0.1*dlat
    # margin_lon = 0.1*dlon
    # origin_lat = min_lat - margin_lat
    # origin_lon = min_lon - margin_lon
    # dlat = (dlat + 2*margin_lat)
    # dlon = (dlon + 2*margin_lon)
    dx_lat = vp_height/total_x
    dy_lon = vp_width/total_y
    Display.Scenic.PlannerOrigin.new_origin(origin_lat, origin_lon, dx_lat, dy_lon)
  end

  @spec draw_waypoints(map(), struct(), list()) :: map()
  def draw_waypoints(graph, origin, waypoints) do
    Enum.reduce(waypoints, graph, fn (wp, acc) ->
      {x, y} = Display.Scenic.PlannerOrigin.get_xy(origin, wp.latitude, wp.longitude)
      Logger.info("#{wp.name} xy: #{x}/#{y}")
      circle(acc, 10, fill: :red, translate: {y, 600-x} )
      |> text(wp.name, translate: {y, 600-x})
    end)
  end

end
