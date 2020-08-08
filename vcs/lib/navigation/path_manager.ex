defmodule Navigation.PathManager do
  use GenServer
  require Logger

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
    {goals_classification, goals_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :goals)
    {:ok, %{
        vehicle_type: vehicle_type,
        vehicle_loiter_speed: config.vehicle_loiter_speed,
        vehicle_agl_ground_threshold: config.vehicle_agl_ground_threshold,
        vehicle_takeoff_speed: config.vehicle_takeoff_speed,
        # vehicle_max_ground_speed: config.vehicle_max_ground_speed,
        goals_classification: goals_classification,
        goals_time_validity_ms: goals_time_validity_ms,
        config_points: [],
        current_cp_index: nil,
        current_path_case: nil,
        current_path_distance: 0,
        path_follower: Navigation.Path.PathFollower.new(config.path_follower.k_path, config.path_follower.k_orbit, config.path_follower.chi_inf)
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:pv_values, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, :load_mission, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:load_mission, mission}, state) do
    Logger.debug("path manager load mission: #{inspect(mission)}")
    {config_points, current_path_distance} = new_path(mission.waypoints, mission.vehicle_turn_rate)
    current_cp = Enum.at(config_points, 0)
    current_path_case = Enum.at(current_cp.dubins.path_cases,0)
    state = %{
      state |
      config_points: config_points,
      current_cp_index: 0,
      current_path_case: current_path_case,
      current_path_distance: current_path_distance
    }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, position, velocity, _dt}, state) do
    # Determine path_case
    # Get vehicle_cmds
    # Send to Navigator
    speed = velocity.speed
    course = velocity.course
    airspeed = velocity.airspeed
    current_case_index = if is_nil(state.current_path_case), do: -1, else: state.current_path_case.case_index
    state = move_vehicle(position, state, current_case_index)
    current_path_case = state.current_path_case
    # If we have a path_case, then follow it
    unless is_nil(current_path_case) do
      # Logger.info("cpc_i: #{current_path_case.case_index}")
      {speed_cmd, course_cmd, altitude_cmd} = Navigation.Path.PathFollower.follow(state.path_follower, position, course, speed, current_path_case)
      goals = %{speed: speed_cmd, altitude: altitude_cmd}
      path_case_type = current_path_case.type
      goals =
      if (path_case_type == Navigation.Path.Waypoint.ground_type()) or (path_case_type == Navigation.Path.Waypoint.landing_type()) do
        if (position.agl < state.vehicle_agl_ground_threshold) do
          if (path_case_type == Navigation.Path.Waypoint.ground_type()) and (speed < state.vehicle_takeoff_speed) do
            Map.put(goals, :altitude, position.altitude)
          else
            goals
          end
          |> Map.put(:course_ground, course_cmd)
        else
          Map.put(goals, :course_flight, course_cmd)
        end
      else
        Map.put(goals, :course_flight, course_cmd)
      end
      # Logger.info("cp_index/path_case: #{current_cp_index}/#{current_path_case.case_index}")
      # Logger.info("spd/course/alt: #{Common.Utils.eftb(speed_cmd,1)}/#{Common.Utils.eftb(Common.Utils.Math.rad2deg(course_cmd),1)}/#{Common.Utils.eftb(altitude_cmd,1)}")
      # Logger.debug("course/cmd: #{Common.Utils.eftb_deg(course, 1)}/#{Common.Utils.eftb_deg(course_cmd, 1)}")
      # Send goals to message sorter
      MessageSorter.Sorter.add_message({:goals, 3}, state.goals_classification, state.goals_time_validity_ms, goals)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:begin_orbit, state) do
    # Create orbit path case, and load it
    path_case = nil
    {:noreply, %{state | current_path_case: path_case}}
  end

  @impl GenServer
  def handle_call(:get_config_points, _from, state) do
    {:reply, state.config_points, state}
  end

  @impl GenServer
  def handle_call(:get_current_path_distance, _from, state) do
    {:reply, state.current_path_distance, state}
  end

  @impl GenServer
  def handle_call({:get_dubins, cp_index},_from, state) do
    cp = Enum.at(state.config_points, cp_index, %{})
    dubins = Map.get(cp, :dubins)
    {:reply, dubins, state}
  end

  @spec move_vehicle(map(), map(), integer()) :: map()
  def move_vehicle(position, state, path_case_index_prev) do
    temp_case_index =
      case state.current_cp_index do
        nil -> -1
        index ->
          # Logger.info("cp_index/path_case_index: #{index}/#{state.current_path_case.case_index}")
          current_cp = Enum.at(state.config_points, index)
          check_for_path_case_completion(position, current_cp, state.current_path_case)
      end
    {current_cp_index, current_path_case} =
      case temp_case_index do
        -1 ->
          # Logger.error("No config points. Follow path_case if it exists")
          {nil, state.current_path_case}
        5 ->
          # Completed this control point
          # if there is a goto, then go to it
          current_cp = Enum.at(state.config_points, state.current_cp_index)
          current_cp_index =
            case current_cp.goto_upon_completion do
              nil ->
                Logger.warn("no goto, move to cp_index: #{state.current_cp_index + 1}")
                cp_index = state.current_cp_index + 1
                if cp_index >= length(state.config_points) do
                  # No more waypoints
                  Logging.Logger.save_log("mission_complete")
                  nil
                else
                  cp_index
                end
              index ->
                Logger.warn("goto: #{index}")
                index
            end
          case current_cp_index do
            nil -> {nil, nil}
            index ->
              new_dubins = Enum.at(state.config_points, index) |> Map.get(:dubins)
              path_case_index = if (new_dubins.skip_case_0 == true), do: 1, else: 0
              path_case = Enum.at(new_dubins.path_cases, path_case_index)
              {index, path_case}
          end
        index ->
          current_cp = Enum.at(state.config_points, state.current_cp_index)
          {state.current_cp_index, Enum.at(current_cp.dubins.path_cases, index)}
      end
    state = %{state | current_cp_index: current_cp_index, current_path_case: current_path_case}
    if (temp_case_index != path_case_index_prev) do
      move_vehicle(position, state, temp_case_index)
    else
      state
    end
  end

  @spec begin_orbit() :: atom()
  def begin_orbit() do
    GenServer.cast(__MODULE__, :begin_orbit)
  end

  @spec get_dubins_for_cp(integer()) :: struct()
  def get_dubins_for_cp(cp_index) do
    GenServer.call(__MODULE__, {:get_dubins, cp_index})
  end

  @spec check_for_path_case_completion(struct(), struct(), struct()) :: integer()
  def check_for_path_case_completion(position, current_cp, current_path_case) do
    {dx, dy} = Common.Utils.Location.dx_dy_between_points(current_path_case.zi, position)
    h = current_path_case.q.x*dx + current_path_case.q.y*dy
    h_pass = if (h>=0), do: true, else: false
    # Logger.info("h/h_pass: #{h}/#{h_pass}")
    case current_path_case.case_index do
      0 -> if (h_pass or (current_cp.dubins.skip_case_0 == true)), do: 1, else: 0
      1 -> if h_pass, do: 2, else: 1
      2 ->
        if h_pass do
          if (current_cp.dubins.skip_case_3 == true), do: 4, else: 3
        else
          2
        end
      3 -> if h_pass, do: 4, else: 3
      4 -> if h_pass, do: 5, else: 4
    end
  end

  @spec new_path(list(), float()) :: list()
  def new_path(waypoints,  vehicle_turn_rate) do
    num_wps = length(waypoints)
    Logger.info("calculate new path with : #{num_wps} waypoints")
    wps_with_index = Enum.with_index(waypoints)
    Enum.reduce(wps_with_index, {[], 0}, fn ({wp, index }, {cp_list, total_path_distance}) ->
      # Logger.info("index/max_index: #{index}/#{num_wps-1}")
      if (index < num_wps-1) do
        current_cp = Navigation.Dubins.ConfigPoint.new(wp, vehicle_turn_rate)
        next_wp = Enum.at(waypoints, index+1)
        next_cp = Navigation.Dubins.ConfigPoint.new(next_wp, vehicle_turn_rate)
        current_cp = %{current_cp | end_speed: next_cp.start_speed, goto_upon_completion: next_wp.goto}
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
        {best_distance, _best_index} = acc
        if (cp.path_distance < best_distance) do
          {cp.path_distance, index}
        else
          acc
        end
      end)
    if best_path_index < 0 do
      Logger.error("No valid paths available")
      {nil, 0}
    else
      cp = Enum.at(path_config_points, best_path_index)
      q3 = Navigation.Utils.Vector.new(:math.cos(next_cp.course), :math.sin(next_cp.course), 0)

      theta1 = Common.Utils.constrain_angle_to_compass(current_cp.course)
      theta2 = :math.atan2(cp.q1.y, cp.q1.x) |> Common.Utils.constrain_angle_to_compass()
      skip_case_0 = can_skip_case(theta1, theta2, cp.start_direction)
      # Logger.debug("theta1/theta/skip0?: #{Common.Utils.Math.rad2deg(theta1)}/#{Common.Utils.Math.rad2deg(theta2)}/#{skip_case_0}")

      theta1 = :math.atan2(cp.q1.y, cp.q1.x) |> Common.Utils.constrain_angle_to_compass()
      theta2 = :math.atan2(q3.y, q3.x) |> Common.Utils.constrain_angle_to_compass()
      skip_case_3 = can_skip_case(theta1, theta2, cp.end_direction)
      # Logger.debug("theta1/theta/skip3?: #{Common.Utils.Math.rad2deg(theta1)}/#{Common.Utils.Math.rad2deg(theta2)}/#{skip_case_3}")
      # Logger.debug("start/radius: #{current_cp.start_radius}/#{next_cp.start_radius}")
      cp = %{cp |
             start_radius: current_cp.start_radius,
             end_radius: next_cp.start_radius,
             z3: next_cp.pos,
             q3: q3,
             dubins: %{cp.dubins | skip_case_0: skip_case_0, skip_case_3: skip_case_3}
            }
      {cp, best_path_distance}
    end
  end

  @spec set_dubins_parameters(struct()) :: struct()
  def set_dubins_parameters(cp) do
    path_case_0 = Navigation.Dubins.PathCase.new_orbit(0, cp.type)
    path_case_0 = %{
      path_case_0 |
      v_des: cp.start_speed,
      c: cp.cs,
      rho: cp.start_radius,
      turn_direction: cp.start_direction,
      q: Navigation.Utils.Vector.reverse(cp.q1),
      zi: cp.z1
    }

    path_case_1 = %{
      path_case_0 |
      case_index: 1,
      q: cp.q1
    }

    path_case_2 = Navigation.Dubins.PathCase.new_line(2, cp.type)
    path_case_2 = %{
      path_case_2 |
      v_des: cp.end_speed,
      r: cp.z1,
      q: cp.q1,
      zi: cp.z2
    }

    path_case_3 = Navigation.Dubins.PathCase.new_orbit(3, cp.type)
    path_case_3 = %{
      path_case_3 |
      v_des: cp.end_speed,
      c: cp.ce,
      rho: cp.end_radius,
      turn_direction: cp.end_direction,
      q: Navigation.Utils.Vector.reverse(cp.q3),
      zi: cp.z3
    }

    path_case_4 = %{
      path_case_3 |
      case_index: 4,
      q: cp.q3,
    }

    %{cp | dubins: %{cp.dubins | path_cases: [path_case_0, path_case_1, path_case_2, path_case_3, path_case_4]}}
  end

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
    crs = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course + @pi_2)
    # Right End
    cre = Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course + @pi_2)

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
      a3 = Common.Utils.Location.lla_from_point_with_distance(crs, radius1, alpha)
      a4 = Common.Utils.Location.lla_from_point_with_distance(cre, radius2, alpha)
      cs_to_p3 = Common.Utils.Location.dx_dy_between_points(crs, a3)
      p3_to_p4 = Common.Utils.Location.dx_dy_between_points(a3, a4)
      cross_a = Common.Utils.Math.cross_product(p3_to_p4, cs_to_p3)
      {line_start, line_end, v2} =
      if (cross_a < 0) do
        line_start = a3
        line_end = a4
        {line_start, line_end, alpha}
      else
        line_start = Common.Utils.Location.lla_from_point_with_distance(crs, -radius1, alpha)
        line_end = Common.Utils.Location.lla_from_point_with_distance(cre, -radius2, alpha)
        {line_start, line_end, :math.pi() + alpha}
      end

      {lsle_dx, lsle_dy} = Common.Utils.Location.dx_dy_between_points(line_start, line_end)
      s1 = Common.Utils.Math.hypot(lsle_dx, lsle_dy)
      s2 = radius1*Common.Utils.constrain_angle_to_compass(v2 - (cp1.course - @pi_2))
      s3 = radius2*Common.Utils.constrain_angle_to_compass((cp2.course - @pi_2) - v2)
      path_distance = s1 + s2 + s3
      # Logger.warn("RR s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Utils.Vector.new(lsle_dx/s1, lsle_dy/s1, (line_end.altitude-line_start.altitude)/s1)
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
      %Navigation.Dubins.ConfigPoint{path_distance: 1_000_000}
    end
  end

  @spec right_left_path(struct(), struct()) :: struct()
  def right_left_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
  # Right Start
    crs = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course + @pi_2)
    # Left End
    cle= Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course - @pi_2)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(crs, cle)
    xL = Common.Utils.Math.hypot(dx, dy)
    if (xL >= (radius1+radius2)) do
      xL1 = xL*radius1/(radius1 + radius2)
      xL2 = xL*radius2/(radius1 + radius2)
      straight1 = xL1*xL1 - radius1*radius1
      straight2 = xL2*xL2 - radius2*radius2
      v = Common.Utils.angle_between_points(crs, cle)
      # Logger.debug("v: #{v}")
      v2 = v - @pi_2 + :math.asin((radius1 + radius2)/xL)
      # Logger.debug("v2: #{v2}")
      s1 = :math.sqrt(straight1) + :math.sqrt(straight2)
      s2 = radius1*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(v2) - Common.Utils.constrain_angle_to_compass(cp1.course - @pi_2))
      s3 = radius2*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(v2 + :math.pi) - Common.Utils.constrain_angle_to_compass(cp2.course + @pi_2))
      path_distance = s1 + s2 + s3
      # Logger.warn("RL s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Utils.Vector.new(:math.cos(v2 + @pi_2), :math.sin(v2 + @pi_2), (cle.altitude-crs.altitude)/s1)
      z1 = Common.Utils.Location.lla_from_point_with_distance(crs, radius1, v2)
      z2 = Common.Utils.Location.lla_from_point_with_distance(cle, radius2, v2 + :math.pi)
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
      %Navigation.Dubins.ConfigPoint{path_distance: 1_000_000}
    end
  end

  @spec left_right_path(struct(), struct()) :: struct()
  def left_right_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Left Start
    cls = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course - @pi_2)
    # Right End
    cre = Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course + @pi_2)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(cls, cre)
    xL = Common.Utils.Math.hypot(dx, dy)
    if (xL >= (radius1+radius2)) do
      xL1 = xL*radius1/(radius1 + radius2)
      xL2 = xL*radius2/(radius1 + radius2)
      straight1 = xL1*xL1 - radius1*radius1
      straight2 = xL2*xL2 - radius2*radius2
      v = Common.Utils.angle_between_points(cls, cre)
      # Logger.debug("v: #{v}")
      v2 = :math.acos((radius1 + radius2)/xL)
      # Logger.debug("v2: #{v2}")
      s1 = :math.sqrt(straight1) + :math.sqrt(straight2)
      s2 = radius1*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(cp1.course + @pi_2) - Common.Utils.constrain_angle_to_compass(v + v2))
      s3 = radius2*Common.Utils.constrain_angle_to_compass(@two_pi + Common.Utils.constrain_angle_to_compass(cp2.course - @pi_2) - Common.Utils.constrain_angle_to_compass(v + v2 - :math.pi))
      path_distance = s1 + s2 + s3
      # Logger.warn("LR s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Utils.Vector.new(:math.cos(v + v2 - @pi_2), :math.sin(v + v2 - @pi_2), (cre.altitude-cls.altitude)/s1)
      z1 = Common.Utils.Location.lla_from_point_with_distance(cls, radius1, v + v2)
      z2 = Common.Utils.Location.lla_from_point_with_distance(cre, radius2, v + v2 - :math.pi)
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
      %Navigation.Dubins.ConfigPoint{path_distance: 1_000_000}
    end
  end

  @spec left_left_path(struct(), struct()) :: struct()
  def left_left_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Left Start
    cls = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course - @pi_2)
    # Left End
    cle = Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course - @pi_2)

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
      alpha = gamma + beta
      a3 = Common.Utils.Location.lla_from_point_with_distance(cls, radius1, alpha)
      a4 = Common.Utils.Location.lla_from_point_with_distance(cle, radius2, alpha)
      cs_to_p3 = Common.Utils.Location.dx_dy_between_points(cls, a3)
      p3_to_p4 = Common.Utils.Location.dx_dy_between_points(a3, a4)
      cross_a = Common.Utils.Math.cross_product(p3_to_p4, cs_to_p3)
      {line_start, line_end, v2} =
      if (cross_a > 0) do
        line_start = a3
        line_end = a4
        {line_start, line_end, :math.pi + alpha}
      else
        line_start = Common.Utils.Location.lla_from_point_with_distance(cls, -radius1, alpha)
        line_end = Common.Utils.Location.lla_from_point_with_distance(cle, -radius2, alpha)
        {line_start, line_end, alpha}
      end

      {lsle_dx, lsle_dy} = Common.Utils.Location.dx_dy_between_points(line_start, line_end)
      s1 = Common.Utils.Math.hypot(lsle_dx, lsle_dy)
      s2 = radius1*Common.Utils.constrain_angle_to_compass((cp1.course - @pi_2)- v2)
      s3 = radius2*Common.Utils.constrain_angle_to_compass(v2 - (cp2.course - @pi_2))
      path_distance = s1 + s2 + s3
      # Logger.warn("LL s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Utils.Vector.new(lsle_dx/s1, lsle_dy/s1, (cle.altitude - cls.altitude)/s1)
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
      %Navigation.Dubins.ConfigPoint{path_distance: 1_000_000}
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
