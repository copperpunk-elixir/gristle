defmodule Navigation.PathManager do
  use GenServer
  require Logger

  @default_pv_cmds_level 3
  @pi_2 1.5708#79633267948966
  @two_pi 6.2832#185307179586

  def start_link(config) do
    Logger.debug("Start Navigation.PathManager")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    vehicle_type = config.vehicle_type
    vehicle_module = Module.concat([Vehicle, vehicle_type])
    {:ok, %{
      vehicle_type: vehicle_type,
      vehicle_module: vehicle_module,
      vehicle_turn_rate: config.vehicle_turn_rate,
      current_mission: nil,
      config_points: [],
      current_cp: nil,
      current_path: nil,
      current_case: nil,
      current_path_distance: 0,
      position: %{},
      velocity: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:load_mission, mission}, state) do
    {config_points, current_path_distance} = new_path(mission.waypoints, state.vehicle_turn_rate)
    {:noreply, %{state | current_mission: mission, config_points: config_points, current_path_distance: current_path_distance}}
  end

  @impl GenServer
  def handle_call(:get_mission, _from, state) do
    {:reply, state.current_mission, state}
  end

  @impl GenServer
  def handle_call(:get_config_points, _from, state) do
    {:reply, state.config_points, state}
  end

  @impl GenServer
  def handle_call(:get_current_path_distance, _from, state) do
    {:reply, state.current_path_distance, state}
  end

  @spec load_mission(struct()) :: atom()
  def load_mission(mission) do
    GenServer.cast(__MODULE__, {:load_mission, mission})
  end

  @spec get_mission() :: struct()
  def get_mission() do
    GenServer.call(__MODULE__, :get_mission)
  end

  @spec new_path(list(), float()) :: list()
  def new_path(waypoints,  vehicle_turn_rate) do
    num_wps = length(waypoints)
    Logger.info("calculate new path with : #{num_wps} waypoints")
    wps_with_index = Enum.with_index(waypoints)
    Enum.reduce(wps_with_index, {[], 0}, fn ({wp, index }, {cp_list, total_path_distance}) ->
      Logger.info("index/max_index: #{index}/#{num_wps-1}")
      if (index < num_wps-1) do
        current_cp = Navigation.Path.ConfigPoint.new(Enum.at(waypoints, index), vehicle_turn_rate)
        next_cp = Navigation.Path.ConfigPoint.new(Enum.at(waypoints, index+1), vehicle_turn_rate)
        current_cp = %{current_cp | end_speed: next_cp.start_speed}
        {current_cp, best_path_distance} = find_shortest_path_between_config_points(current_cp, next_cp)
        # Logger.info("inspect()")
        if current_cp == nil do
          raise "Invalid path plan"
        else
          current_cp = set_dubins_parameters(current_cp)
          {cp_list ++ [current_cp], total_path_distance + best_path_distance}
        end
      else
        {cp_list, total_path_distance}
      end
    end)
  end

  @spec find_shortest_path_between_config_points(struct(), struct()) :: struct()
  def find_shortest_path_between_config_points(current_cp, next_cp) do
    # current_cp
    path_config_points =
      [right_right_path(current_cp, next_cp),
       right_left_path(current_cp, next_cp),
       left_right_path(current_cp, next_cp),
       left_left_path(current_cp, next_cp)]
    {best_path_distance, best_path_index} =
      Enum.reduce(Enum.with_index(path_config_points), {1_000_000, -1}, fn ({cp, index}, acc) ->
        {best_distance, best_index} = acc
        if (cp.path_distance < best_distance) do
          {cp.path_distance, index}
        else
          acc
        end
      end)
    Logger.debug("best distance/index: #{best_path_distance}/#{best_path_index}")
    case best_path_index do
      0 -> Logger.info("RR")
      1 -> Logger.info("RL")
      2 -> Logger.info("LR")
      3 -> Logger.info("LL")
    end
    if best_path_index < 0 do
      Logger.error("No valid paths available")
      {nil, 0}
    else
      cp = Enum.at(path_config_points, best_path_index)
      q3 = Navigation.Path.Vector.new(:math.cos(next_cp.course), :math.sin(next_cp.course), 0)

      theta1 = Common.Utils.constrain_angle_to_compass(current_cp.course)
      theta2 = :math.atan2(cp.q1.y, cp.q1.x) |> Common.Utils.constrain_angle_to_compass()
      skip_case_0 = can_skip_case(theta1, theta2, cp.start_direction)

      theta1 = :math.atan2(cp.q1.y, cp.q1.x) |> Common.Utils.constrain_angle_to_compass()
      theat2 = :math.atan2(q3.y, q3.x) |> Common.Utils.constrain_angle_to_compass()
      skip_case_3 = can_skip_case(theta1, theta2, cp.end_direction)

      cp = %{cp |
             start_radius: current_cp.start_radius,
             end_radius: next_cp.end_radius,
             z3: next_cp.pos,
             q3: q3,
             dubins: %{cp.dubins | skip_case_0: skip_case_0, skip_case_3: skip_case_3}
            }
      {cp, best_path_distance}
    end
  end

  @spec set_dubins_parameters(struct()) :: struct()


  @spec can_skip_case(float(), float(), integer()) :: boolean()
  def can_skip_case(theta1, theta2, direction) do
    if (abs(theta1-theta2) < 0.0175) or (abs(theta1 - theta2) > 6.2657) do
      true
    else
      theta_diff =
      if direction < 0 do
        theta1 = if (theta1 < theta2), do: theta1 + @two_pi, else: theta1
        theta1-theta2
      else
        theta2 = if (theta2 < theta1), do: theta2 + @two_pi, else: theta2
        theta2 - theta1
      end
      if (theta_diff < @pi_2), do: true, else: false
    end
  end


  @spec right_right_path(struct(), struct()) :: struct()
  def right_right_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Right Start
    {crs_lat, crs_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp1.pos, radius1, cp1.course + @pi_2)
    # Right End
    {cre_lat, cre_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp2.pos, radius2, cp2.course + @pi_2)
    crs = Navigation.Path.LatLonAlt.new(crs_lat, crs_lon, cp1.pos.altitude)
    cre = Navigation.Path.LatLonAlt.new(cre_lat, cre_lon, cp2.pos.altitude)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(crs, cre)
    ell = Common.Utils.Math.hypot(dx, dy)
    if (ell > abs(radius1-radius2)) do
      gamma =
      if (dy == 0) do
        -@pi_2
      else
        -:math.atan(dx/dy)
      end
      beta = :math.asin((radius2-radius1)/ell)
      alpha = gamma - beta
      {a3_lat, a3_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(crs, radius1, alpha)
      {a4_lat, a4_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cre, radius2, alpha)
      a3 = Navigation.Path.LatLonAlt.new(a3_lat, a3_lon, crs.altitude)
      a4 = Navigation.Path.LatLonAlt.new(a4_lat, a4_lon, cre.altitude)
      cs_to_p3 = Common.Utils.Location.dx_dy_between_points(crs, a3)
      p3_to_p4 = Common.Utils.Location.dx_dy_between_points(a3, a4)
      cross_a = Common.Utils.Math.cross_product(p3_to_p4, cs_to_p3)
      {line_start, line_end, v2} =
      if (cross_a < 0) do
        line_start = a3
        line_end = a4
        {line_start, line_end, alpha}
      else
        {b3_lat, b3_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(crs, -radius1, alpha)
        {b4_lat, b4_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cre, -radius2, alpha)
        line_start = Navigation.Path.LatLonAlt.new(b3_lat, b3_lon, crs.altitude)
        line_end = Navigation.Path.LatLonAlt.new(b4_lat, b4_lon, cre.altitude)
        {line_start, line_end, :math.pi() + alpha}
      end

      {lsle_dx, lsle_dy} = Common.Utils.Location.dx_dy_between_points(line_start, line_end)
      s1 = Common.Utils.Math.hypot(lsle_dx, lsle_dy)
      s2 = radius1*Common.Utils.constrain_angle_to_compass(v2 - (cp1.course - @pi_2))
      s3 = radius2*Common.Utils.constrain_angle_to_compass((cp2.course - @pi_2) - v2)
      path_distance = s1 + s2 + s3
      Logger.warn("RR s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q_denom = s1
      q1 = Navigation.Path.Vector.new(lsle_dx/q_denom, lsle_dy/q_denom, crs.altitude)
      %{cp1 |
        cs: crs,
        start_direction: 1,
        ce: cre,
        end_direction: 1,
        q1: q1,
        z1: line_start,
        z2: line_end,
        path_distance: path_distance
      }
    else
      %Navigation.Path.ConfigPoint{path_distance: 1_000_000}
    end
  end

  @spec right_left_path(struct(), struct()) :: struct()
  def right_left_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
  # Right Start
    {crs_lat, crs_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp1.pos, radius1, cp1.course + @pi_2)
    # Left End
    {cle_lat, cle_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp2.pos, radius2, cp2.course - @pi_2)
    crs = Navigation.Path.LatLonAlt.new(crs_lat, crs_lon, cp1.pos.altitude)
    cle = Navigation.Path.LatLonAlt.new(cle_lat, cle_lon, cp2.pos.altitude)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(crs, cle)
    xL = Common.Utils.Math.hypot(dx, dy)
    if (xL >= (radius1+radius2)) do
      xL1 = xL*radius1/(radius1 + radius2)
      xL2 = xL*radius2/(radius1 + radius2)
      straight1 = xL1*xL1 - radius1*radius2
      straight2 = xL2*xL2 - radius2*radius2
      v = Common.Utils.angle_between_points(crs, cle)
      # Logger.debug("v: #{v}")
      v2 = v - @pi_2 + :math.asin((radius1 + radius2)/xL)
      # Logger.debug("v2: #{v2}")
      s1 = :math.sqrt(straight1) + :math.sqrt(straight2)
      s2 = radius1*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(v2) - Common.Utils.constrain_angle_to_compass(cp1.course - @pi_2))
      s3 = radius2*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(v2 + :math.pi) - Common.Utils.constrain_angle_to_compass(cp2.course + @pi_2))
      path_distance = s1 + s2 + s3
      Logger.warn("RL s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Path.Vector.new(:math.cos(v2 + @pi_2), :math.sin(v2 + @pi_2), 0)
      {z1_lat, z1_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(crs, radius1, v2)
      {z2_lat, z2_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cle, radius2, v2 + :math.pi)
      z1 = Navigation.Path.LatLonAlt.new(z1_lat, z1_lon, crs.altitude)
      z2 = Navigation.Path.LatLonAlt.new(z2_lat, z2_lon, cle.altitude)
      %{cp1 |
        cs: crs,
        start_direction: 1,
        ce: cle,
        end_direction: -1,
        q1: q1,
        z1: z1,
        z2: z2,
        path_distance: path_distance
      }
    else
      %Navigation.Path.ConfigPoint{path_distance: 1_000_000}
    end
  end

  @spec left_right_path(struct(), struct()) :: struct()
  def left_right_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Left Start
    {cls_lat, cls_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp1.pos, radius1, cp1.course - @pi_2)
    # Right End
    {cre_lat, cre_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp2.pos, radius2, cp2.course + @pi_2)
    cls = Navigation.Path.LatLonAlt.new(cls_lat, cls_lon, cp1.pos.altitude)
    cre = Navigation.Path.LatLonAlt.new(cre_lat, cre_lon, cp2.pos.altitude)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(cls, cre)
    xL = Common.Utils.Math.hypot(dx, dy)
    if (xL >= (radius1+radius2)) do
      xL1 = xL*radius1/(radius1 + radius2)
      xL2 = xL*radius2/(radius1 + radius2)
      straight1 = xL1*xL1 - radius1*radius2
      straight2 = xL2*xL2 - radius2*radius2
      v = Common.Utils.angle_between_points(cls, cre)
      # Logger.debug("v: #{v}")
      v2 = :math.acos((radius1 + radius2)/xL)
      # Logger.debug("v2: #{v2}")
      s1 = :math.sqrt(straight1) + :math.sqrt(straight2)
      s2 = radius1*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(cp1.course + @pi_2) - Common.Utils.constrain_angle_to_compass(v + v2))
      s3 = radius2*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(cp2.course - @pi_2) - Common.Utils.constrain_angle_to_compass(v + v2 - :math.pi))
      path_distance = s1 + s2 + s3
      Logger.warn("LR s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Path.Vector.new(:math.cos(v + v2 - @pi_2), :math.sin(v + v2 - @pi_2), 0)
      {z1_lat, z1_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cls, radius1, v + v2)
      {z2_lat, z2_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cre, radius2, v + v2 - :math.pi)
      z1 = Navigation.Path.LatLonAlt.new(z1_lat, z1_lon, cls.altitude)
      z2 = Navigation.Path.LatLonAlt.new(z2_lat, z2_lon, cre.altitude)
      %{cp1 |
        cs: cls,
        start_direction: -1,
        ce: cre,
        end_direction: 1,
        q1: q1,
        z1: z1,
        z2: z2,
        path_distance: path_distance
      }
    else
      %Navigation.Path.ConfigPoint{path_distance: 1_000_000}
    end
  end

  @spec left_left_path(struct(), struct()) :: struct()
  def left_left_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Left Start
    {cls_lat, cls_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp1.pos, radius1, cp1.course - @pi_2)
    # Left End
    {cle_lat, cle_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cp2.pos, radius2, cp2.course - @pi_2)
    cls = Navigation.Path.LatLonAlt.new(cls_lat, cls_lon, cp1.pos.altitude)
    cle = Navigation.Path.LatLonAlt.new(cle_lat, cle_lon, cp2.pos.altitude)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(cls, cle)
    ell = Common.Utils.Math.hypot(dx, dy)
    if (ell > abs(radius1-radius2)) do
      gamma =
      if (dy == 0) do
        -@pi_2
      else
        -:math.atan(dx/dy)
      end
      beta = :math.asin((radius2-radius1)/ell)
      alpha = gamma - beta
      {a3_lat, a3_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cls, radius1, alpha)
      {a4_lat, a4_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cle, radius2, alpha)
      a3 = Navigation.Path.LatLonAlt.new(a3_lat, a3_lon, cls.altitude)
      a4 = Navigation.Path.LatLonAlt.new(a4_lat, a4_lon, cle.altitude)
      cs_to_p3 = Common.Utils.Location.dx_dy_between_points(cls, a3)
      p3_to_p4 = Common.Utils.Location.dx_dy_between_points(a3, a4)
      cross_a = Common.Utils.Math.cross_product(p3_to_p4, cs_to_p3)
      {line_start, line_end, v2} =
      if (cross_a > 0) do
        line_start = a3
        line_end = a4
        {line_start, line_end, :math.pi + alpha}
      else
        {b3_lat, b3_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cls, -radius1, alpha)
        {b4_lat, b4_lon} = Common.Utils.Location.lat_lon_from_point_with_distance(cle, -radius2, alpha)
        line_start = Navigation.Path.LatLonAlt.new(b3_lat, b3_lon, cls.altitude)
        line_end = Navigation.Path.LatLonAlt.new(b4_lat, b4_lon, cle.altitude)
        {line_start, line_end, alpha}
      end

      {lsle_dx, lsle_dy} = Common.Utils.Location.dx_dy_between_points(line_start, line_end)
      s1 = Common.Utils.Math.hypot(lsle_dx, lsle_dy)
      s2 = radius1*Common.Utils.constrain_angle_to_compass((cp1.course - @pi_2)- v2)
      s3 = radius2*Common.Utils.constrain_angle_to_compass(v2 - (cp2.course - @pi_2))
      path_distance = s1 + s2 + s3
      Logger.warn("LL s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q_denom = s1
      q1 = Navigation.Path.Vector.new(lsle_dx/q_denom, lsle_dy/q_denom, cls.altitude)
      %{cp1 |
        cs: cls,
        start_direction: -1,
        ce: cle,
        end_direction: -1,
        q1: q1,
        z1: line_start,
        z2: line_end,
        path_distance: path_distance
      }
    else
      %Navigation.Path.ConfigPoint{path_distance: 1_000_000}
    end
  end


  @spec get_config_points() :: struct()
  def get_config_points() do
    GenServer.call(__MODULE__, :get_config_points)
  end

  @spec get_radius_for_speed_and_turn(float(), float()) :: float()
  def get_radius_for_speed_and_turn(speed, turn_rate) do
    speed/turn_rate
  end

  @spec get_current_path_distance() :: float()
  def get_current_path_distance() do
    GenServer.call(__MODULE__, :get_current_path_distance)
  end

end


