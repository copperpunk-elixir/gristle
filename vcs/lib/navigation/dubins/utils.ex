defmodule Navigation.Dubins.Utils do
  require Logger
  require Common.Constants, as: CC

  @spec check_for_path_case_completion(struct(), struct(), struct()) :: integer()
  def check_for_path_case_completion(position, current_cp, current_path_case) do
    {dx, dy} = Common.Utils.Location.dx_dy_between_points(current_path_case.zi, position)
    h = current_path_case.q.x*dx + current_path_case.q.y*dy
    h_pass = (h>=0)
    # Logger.debug("h/h_pass: #{h}/#{h_pass}")
    case current_path_case.case_index do
      0 -> if h_pass or current_cp.dubins.skip_case_0, do: 1, else: 0
      1 -> if h_pass, do: 2, else: 1
      2 ->
        if h_pass do
          if current_cp.dubins.skip_case_3, do: 4, else: 3
        else
          2
        end
      3 -> if h_pass, do: 4, else: 3
      4 -> if h_pass, do: 5, else: 4
    end
  end

  @spec config_points_from_waypoints(list(), float()) :: tuple()
  def config_points_from_waypoints(waypoints,  vehicle_turn_rate) do
    num_wps = length(waypoints)
    Logger.debug("calculate new path with : #{num_wps} waypoints")
    wps_with_index = Enum.with_index(waypoints)
    Enum.reduce(wps_with_index, {[], 0}, fn ({wp, index }, {cp_list, total_path_distance}) ->
      # Logger.debug("index/max_index: #{index}/#{num_wps-1}")
      if (index < num_wps-1) do
        current_cp = Navigation.Dubins.ConfigPoint.new(wp, vehicle_turn_rate)
        next_wp = Enum.at(waypoints, index+1)
        next_cp = Navigation.Dubins.ConfigPoint.new(next_wp, vehicle_turn_rate)
        current_cp = %{current_cp | end_speed: next_cp.start_speed, goto_upon_completion: next_wp.goto}
        current_cp = find_shortest_path_between_config_points(current_cp, next_cp)
        # Logger.debug("inspect()")
        if is_nil(current_cp) do
          raise "Invalid path plan"
        else
          current_cp = set_dubins_parameters(current_cp)
          {cp_list ++ [current_cp], total_path_distance + current_cp.path_distance}
        end
      else
        {cp_list, total_path_distance}
      end
    end)
  end

  @spec find_shortest_path_between_config_points(struct(), struct()) :: struct()
  def find_shortest_path_between_config_points(current_cp, next_cp) do
    # Logger.debug("current/next: #{inspect(current_cp)}/#{inspect(next_cp)}")
    # current_cp
    path_config_points =
      [right_right_path(current_cp, next_cp),
       right_left_path(current_cp, next_cp),
       left_right_path(current_cp, next_cp),
       left_left_path(current_cp, next_cp)]

    cp =
      Enum.reject(path_config_points, &(&1.path_distance < 0))
      |> Enum.sort(&(&1.path_distance < &2.path_distance))
      |> Enum.at(0)

    if is_nil(cp) do
      Logger.error("No valid paths available")
      nil
    else
      q3 = Navigation.Utils.Vector.new(:math.cos(next_cp.course), :math.sin(next_cp.course), 0)

      theta1 = Common.Utils.Motion.constrain_angle_to_compass(current_cp.course)
      theta2 = :math.atan2(cp.q1.y, cp.q1.x) |> Common.Utils.Motion.constrain_angle_to_compass()
      skip_case_0 = can_skip_case(theta1, theta2, cp.start_direction)
      # Logger.debug("theta1/theta/skip0?: #{Common.Utils.Math.rad2deg(theta1)}/#{Common.Utils.Math.rad2deg(theta2)}/#{skip_case_0}")

      theta1 = :math.atan2(cp.q1.y, cp.q1.x) |> Common.Utils.Motion.constrain_angle_to_compass()
      theta2 = :math.atan2(q3.y, q3.x) |> Common.Utils.Motion.constrain_angle_to_compass()
      skip_case_3 = can_skip_case(theta1, theta2, cp.end_direction)
      # Logger.debug("theta1/theta/skip3?: #{Common.Utils.Math.rad2deg(theta1)}/#{Common.Utils.Math.rad2deg(theta2)}/#{skip_case_3}")
      # Logger.debug("start/radius: #{current_cp.start_radius}/#{next_cp.start_radius}")
      %{cp |
        start_radius: current_cp.start_radius,
        end_radius: next_cp.start_radius,
        z3: next_cp.pos,
        q3: q3,
        dubins: %{cp.dubins | skip_case_0: skip_case_0, skip_case_3: skip_case_3}
      }
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

    path_cases = [path_case_0, path_case_1, path_case_2, path_case_3, path_case_4]
    %{cp | dubins: %{cp.dubins | path_cases: path_cases}}
  end

  @spec can_skip_case(float(), float(), integer()) :: boolean()
  def can_skip_case(theta1, theta2, direction) do
    if (abs(theta1-theta2) < 0.0175) or (abs(theta1 - theta2) > 6.2657) do
      true
    else
      theta_diff =
      if direction < 0 do
        theta1 = if (theta1 < theta2), do: theta1 + CC.two_pi, else: theta1
        theta1-theta2
      else
        theta2 = if (theta2 < theta1), do: theta2 + CC.two_pi, else: theta2
        theta2 - theta1
      end
      if (theta_diff < CC.pi_2), do: true, else: false
    end
  end


  @spec right_right_path(struct(), struct()) :: struct()
  def right_right_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Right Start
    crs = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course + CC.pi_2)
    # Right End
    cre = Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course + CC.pi_2)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(crs, cre)
    ell = Common.Utils.Math.hypot(dx, dy)
    if (ell > abs(radius1-radius2)) do
      gamma =
      if (dy == 0) do
        -CC.pi_2
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
      s2 = radius1*Common.Utils.Motion.constrain_angle_to_compass(v2 - (cp1.course - CC.pi_2))
      s3 = radius2*Common.Utils.Motion.constrain_angle_to_compass((cp2.course - CC.pi_2) - v2)
      path_distance = s1 + s2 + s3
      # Logger.debug("RR s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
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
      %Navigation.Dubins.ConfigPoint{path_distance: -1}
    end
  end

  @spec right_left_path(struct(), struct()) :: struct()
  def right_left_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
  # Right Start
    crs = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course + CC.pi_2)
    # Left End
    cle= Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course - CC.pi_2)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(crs, cle)
    xL = Common.Utils.Math.hypot(dx, dy)
    if (xL >= (radius1+radius2)) do
      xL1 = xL*radius1/(radius1 + radius2)
      xL2 = xL*radius2/(radius1 + radius2)
      straight1 = xL1*xL1 - radius1*radius1
      straight2 = xL2*xL2 - radius2*radius2
      v = Common.Utils.Motion.angle_between_points(crs, cle)
      # Logger.debug("v: #{v}")
      v2 = v - CC.pi_2 + :math.asin((radius1 + radius2)/xL)
      # Logger.debug("v2: #{v2}")
      s1 = :math.sqrt(straight1) + :math.sqrt(straight2)
      s2 = radius1*Common.Utils.Motion.constrain_angle_to_compass(CC.two_pi + Common.Utils.Motion.constrain_angle_to_compass(v2) - Common.Utils.Motion.constrain_angle_to_compass(cp1.course - CC.pi_2))
      s3 = radius2*Common.Utils.Motion.constrain_angle_to_compass(CC.two_pi + Common.Utils.Motion.constrain_angle_to_compass(v2 + :math.pi) - Common.Utils.Motion.constrain_angle_to_compass(cp2.course + CC.pi_2))
      path_distance = s1 + s2 + s3
      # Logger.debug("RL s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Utils.Vector.new(:math.cos(v2 + CC.pi_2), :math.sin(v2 + CC.pi_2), (cle.altitude-crs.altitude)/s1)
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
      %Navigation.Dubins.ConfigPoint{path_distance: -1}
    end
  end

  @spec left_right_path(struct(), struct()) :: struct()
  def left_right_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Left Start
    cls = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course - CC.pi_2)
    # Right End
    cre = Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course + CC.pi_2)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(cls, cre)
    xL = Common.Utils.Math.hypot(dx, dy)
    if (xL >= (radius1+radius2)) do
      xL1 = xL*radius1/(radius1 + radius2)
      xL2 = xL*radius2/(radius1 + radius2)
      straight1 = xL1*xL1 - radius1*radius1
      straight2 = xL2*xL2 - radius2*radius2
      v = Common.Utils.Motion.angle_between_points(cls, cre)
      # Logger.debug("v: #{v}")
      v2 = :math.acos((radius1 + radius2)/xL)
      # Logger.debug("v2: #{v2}")
      s1 = :math.sqrt(straight1) + :math.sqrt(straight2)
      s2 = radius1*Common.Utils.Motion.constrain_angle_to_compass(CC.two_pi + Common.Utils.Motion.constrain_angle_to_compass(cp1.course + CC.pi_2) - Common.Utils.Motion.constrain_angle_to_compass(v + v2))
      s3 = radius2*Common.Utils.Motion.constrain_angle_to_compass(CC.two_pi + Common.Utils.Motion.constrain_angle_to_compass(cp2.course - CC.pi_2) - Common.Utils.Motion.constrain_angle_to_compass(v + v2 - :math.pi))
      path_distance = s1 + s2 + s3
      # Logger.debug("LR s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
      q1 = Navigation.Utils.Vector.new(:math.cos(v + v2 - CC.pi_2), :math.sin(v + v2 - CC.pi_2), (cre.altitude-cls.altitude)/s1)
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
      %Navigation.Dubins.ConfigPoint{path_distance: -1}
    end
  end

  @spec left_left_path(struct(), struct()) :: struct()
  def left_left_path(cp1, cp2) do
    radius1 = cp1.start_radius
    radius2 = cp2.start_radius
    # Left Start
    cls = Common.Utils.Location.lla_from_point_with_distance(cp1.pos, radius1, cp1.course - CC.pi_2)
    # Left End
    cle = Common.Utils.Location.lla_from_point_with_distance(cp2.pos, radius2, cp2.course - CC.pi_2)

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(cls, cle)
    ell = Common.Utils.Math.hypot(dx, dy)
    if (ell > abs(radius1-radius2)) do
      gamma =
      if (dy == 0) do
        -CC.pi_2
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
      s2 = radius1*Common.Utils.Motion.constrain_angle_to_compass((cp1.course - CC.pi_2)- v2)
      s3 = radius2*Common.Utils.Motion.constrain_angle_to_compass(v2 - (cp2.course - CC.pi_2))
      path_distance = s1 + s2 + s3
      # Logger.debug("LL s1/s2/s3/tot: #{s1}/#{s2}/#{s3}/#{path_distance}")
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
      %Navigation.Dubins.ConfigPoint{path_distance: -1}
    end
  end
end
