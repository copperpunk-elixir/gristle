defmodule Navigation.Path.PathFollower do
  require Logger
  @pi_2 1.5708#79633267948966
  @two_pi 6.2832#185307179586

  @enforce_keys [:k_path, :k_orbit, :chi_inf_two_over_pi, :lookahead_dt]

  defstruct [:k_path, :k_orbit, :chi_inf_two_over_pi, :lookahead_dt]


  @spec new(list) :: struct()
  def new(config) do
    new(Keyword.fetch!(config, :k_path),Keyword.fetch!(config, :k_orbit),Keyword.fetch!(config, :chi_inf),Keyword.fetch!(config, :lookahead_dt))
  end

  @spec new(float(), float(), float(), float()) :: struct()
  def new(k_path, k_orbit, chi_inf, lookahead_dt) do
    %Navigation.Path.PathFollower{
      k_path: k_path,
      k_orbit: k_orbit,
      chi_inf_two_over_pi: chi_inf*2.0/:math.pi,
      lookahead_dt: lookahead_dt
    }
  end

  @spec follow(struct(), struct(), float(), float(), struct()) :: map()
  def follow(path_follower, position, course, speed, path_case) do
    if path_case.flag == Navigation.Dubins.PathCase.line_flag() do
      position = get_lookahead_position(position, speed, course, path_follower.lookahead_dt)
      {dx, dy} = Common.Utils.Location.dx_dy_between_points(path_case.r, position)
      # Logger.debug("post look: #{dx}/#{dy}")
     # Add lookahead
      q = path_case.q
      temp_vector = q.x*dy - q.y*dx
      si1 = dx + q.y*temp_vector
      si2 = dy - q.x*temp_vector
      # Logger.debug("r.alt/ q.z / si1 / si2: #{path_case.r.altitude}/#{q.z}/#{si1}/#{si2}")
      altitude_cmd =
      if path_case.type == Navigation.Path.Waypoint.approach_type() or path_case.type == Navigation.Path.Waypoint.climbout_type() do
        landing_distance =
          Common.Utils.Location.dx_dy_between_points(path_case.r, path_case.zi)
          |> Common.Utils.Math.hypot()
        d_alt_landing = path_case.zi.altitude - path_case.r.altitude
        landing_distance_travelled = Common.Utils.Math.hypot(si1, si2)
        d_alt = 0.5*d_alt_landing*(:math.cos(:math.pi()*(1.0-landing_distance_travelled/landing_distance))+1)
        # Logger.debug("landing: #{landing_distance_travelled}/#{landing_distance}/#{d_alt}")
        path_case.r.altitude + d_alt
      else
        path_case.r.altitude + (q.z*Common.Utils.Math.hypot(si1, si2) / Common.Utils.Math.hypot(q.x, q.y))
      end
      chi_q = :math.atan2(q.y, q.x)
      chi_q = if ((chi_q - course) < -:math.pi), do: chi_q + @two_pi, else: chi_q
      chi_q = if ((chi_q - course) > :math.pi), do: chi_q - @two_pi, else: chi_q
      sin_chi_q = :math.sin(chi_q)
      cos_chi_q = :math.cos(chi_q)

      # e_px = cos_chi_q*dx + sin_chi_q*dy
      e_py = -sin_chi_q*dx + cos_chi_q*dy
      course_cmd = chi_q - path_follower.chi_inf_two_over_pi*:math.atan(path_follower.k_path*e_py)
      |> Common.Utils.Motion.constrain_angle_to_compass()
      # Logger.debug("e_py/course_cmd: #{Common.Utils.eftb(e_py,2)}/#{Common.Utils.eftb_deg(course_cmd,1)}")
      # d_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd- course)
      # Logger.debug("e_py/course_cmd: #{Common.Utils.eftb(e_py,2)}/#{Common.Utils.eftb_deg(d_course,1)}")
      {path_case.v_des, course_cmd, altitude_cmd}
    else
      altitude_cmd = path_case.c.altitude
      distance_to_z1 =
      if is_nil(path_case.zi) do
        1_000_000_000
      else
        Common.Utils.Location.dx_dy_between_points(path_case.zi,position)
        |> Common.Utils.Math.hypot()
      end
      # Only use lookahead position if we are far enough away from the transition to the next path case
      position = if (abs(distance_to_z1) > speed*1.0) or path_case.case_index == 0 or path_case.case_index == 3 do
        get_lookahead_position(position, speed, course, path_follower.lookahead_dt)
      else
        position
      end
      {dx, dy} = Common.Utils.Location.dx_dy_between_points(path_case.c, position)
      # Logger.debug("post look: #{dx}/#{dy}")
      orbit_d = Common.Utils.Math.hypot(dx, dy)
      phi = :math.atan2(dy, dx)
      phi = if ((phi - course) < -:math.pi), do: phi + @two_pi, else: phi
      phi = if ((phi - course) > :math.pi), do: phi - @two_pi, else: phi
      course_cmd = phi + path_case.turn_direction*(@pi_2 + :math.atan(path_follower.k_orbit*(orbit_d - path_case.rho)/path_case.rho))
      |> Common.Utils.Motion.constrain_angle_to_compass()

      # e_py = orbit_d - path_case.rho
      # Logger.debug("orbit_d/rho: #{Common.Utils.eftb(orbit_d,2)}/#{Common.Utils.eftb(path_case.rho,2)}")
      # d_course = Common.Utils.Motion.turn_left_or_right_for_correction(course_cmd- course)
      # Logger.debug("e_py/course_cmd: #{Common.Utils.eftb(e_py,2)}/#{Common.Utils.eftb_deg(d_course,1)}")
      {path_case.v_des, course_cmd, altitude_cmd}
    end
  end

  @spec get_lookahead_position(struct(), float(), float(), float()) :: struct()
  def get_lookahead_position(position, speed, course, dt) do
    look_dx = speed*dt*:math.cos(course)
    look_dy = speed*dt*:math.sin(course)
    Common.Utils.Location.lla_from_point(position, look_dx, look_dy)
  end
end
