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
      |> Display.Scenic.Gcs.Utils.draw_arrow(0,0, 0, 1, :vehicle, true, :clear)
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
    bounding_box = calculate_lat_lon_bounding_box(mission, vehicle_position)
    origin = calculate_origin(bounding_box, state.width, state.height)
    Logger.debug("bounding box: #{inspect(bounding_box)}")
    graph = draw_waypoints(state.graph, origin, mission.waypoints)
    state = Map.put(state, :mission, mission)
    |> Map.put(:origin, origin)
    |> Map.put(:graph, graph)
    {:noreply, state, push: graph }
  end

  def handle_cast({:pv_estimate, pv_value_map}, state) do
    position = pv_value_map.position
    yaw = pv_value_map.attitude.yaw
    speed = pv_value_map.calculated.speed
    vehicle = %{position: position, yaw: yaw, speed: speed}
    origin =
    if Map.get(state, :origin) == nil do
      bounding_box = calculate_lat_lon_bounding_box(%{}, position)
      calculate_origin(bounding_box, state.width, state.height)
    else
      state.origin
    end
    graph = draw_vehicle(state.graph, origin, vehicle)
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
    {min_lat, max_lat, min_lon, max_lon}
  end

  @spec calculate_origin(tuple(), integer(), integer()) :: tuple()
  def calculate_origin(bounding_box, vp_width, vp_height) do
    {min_lat, max_lat, min_lon, max_lon} = bounding_box
    aspect_ratio = vp_width/vp_height
    dx_dist_from_lat = max_lat-min_lat
    dy_dist_from_lon = (max_lon-min_lon)/:math.sqrt(2)
    gap_x = 1/dx_dist_from_lat
    gap_y = aspect_ratio/dy_dist_from_lon
    margin = 0.2
    {origin_lat, origin_lon, total_x, total_y} =
    if (gap_x < gap_y) do
      total_dist_x = (1+2*margin)*dx_dist_from_lat
      origin_x = min_lat - margin*dx_dist_from_lat
      total_dist_y = aspect_ratio*total_dist_x*:math.sqrt(2)
      margin_y = (total_dist_y - dy_dist_from_lon*:math.sqrt(2))/2
      origin_y = min_lon - margin_y
      {origin_x, origin_y, total_dist_x, total_dist_y}
    else
      total_dist_y = (1+2*margin)*dy_dist_from_lon*:math.sqrt(2)
      origin_y = min_lon - margin*dy_dist_from_lon*:math.sqrt(2)
      total_dist_x = total_dist_y/aspect_ratio
      margin_x = (total_dist_x - dx_dist_from_lat)/2
      origin_x = min_lat - margin_x
      {origin_x, origin_y, total_dist_x, total_dist_y}
    end
    dx_lat = vp_height/total_x
    dy_lon = vp_width/total_y
    Display.Scenic.PlannerOrigin.new_origin(origin_lat, origin_lon, dx_lat, dy_lon)
  end

  # @spec get_origin_without_mission(float(), float()) :: struct()
  # def get_boundary_without_mission(lat, lon, vp_width, vp_height) do
  #   dLat = 0.001
  #   dLon = dLat*sqrt(2)
  #   bounding_box = {lat - dLat, lat + dLat, lon - dLon, lon + dLon}
  # end

  @spec draw_waypoints(map(), struct(), list()) :: map()
  def draw_waypoints(graph, origin, waypoints) do
    Enum.reduce(waypoints, graph, fn (wp, acc) ->
      {y_plot, x_plot} = Display.Scenic.PlannerOrigin.get_xy(origin, wp.latitude, wp.longitude)
      Logger.info("#{wp.name} xy: #{x_plot}/#{y_plot}")
      circle(acc, 10, fill: :red, translate: {x_plot, 600-x_plot} )
      |> text(wp.name, translate: {x_plot, 600-y_plot})
    end)
  end

  @spec draw_vehicle(map(), struct(), map()) :: map()
  def draw_vehicle(graph, origin, vehicle) do
    {y_plot,x_plot} = Display.Scenic.PlannerOrigin.get_xy(origin, vehicle.position.latitude, vehicle.position.longitude)
    vehicle_size = ceil(vehicle.speed/10) + 10
    Display.Scenic.Gcs.Utils.draw_arrow(graph, x_plot, 600-y_plot, vehicle.yaw, vehicle_size, :vehicle)
  end

end
