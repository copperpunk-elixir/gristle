defmodule Navigation.Path.PathFollower do
  require Logger
  @pi_2 1.5708#79633267948966
  @two_pi 6.2832#185307179586

  @enforce_keys [:k_path, :k_orbit, :chi_inf_over_two_pi]

  defstruct [:k_path, :k_orbit, :chi_inf_over_two_pi]

  @spec new(float(), float(), float()) :: struct()
  def new(k_path, k_orbit, chi_inf) do
    %Navigation.Path.PathFollower{
      k_path: k_path,
      k_orbit: k_orbit,
      chi_inf_over_two_pi: 0.5*chi_inf / :math.pi
    }
  end

  @spec follow(struct(), struct(), float(), struct()) :: map()
  def follow(path_follower, position, course, path_case) do
    if path_case.flag == Navigation.Path.PathCase.line_flag() do
      {dx, dy} = Common.Utils.Location.dx_dy_between_points(path_case.r, position)
      q = path_case.q
      temp_vector = q.x*dy - q.y*dx
      si1 = dx + q.y*temp_vector
      si2 = dy - q.x*temp_vector
      altitude_cmd = path_case.r.altitude - (q.z*Common.Utils.Math.hypot(si1, si2) / Common.Utils.Math.hypot(q.x, q.y))
      # Logger.debug("q: #{Navigation.Path.Vector.to_string(q)}")
      # Logger.debug("r.alt: #{path_case.r.altitude}")
      # Logger.debug("si1/si2: #{si1}/#{si2}")
      # Logger.debug("num/denom: #{q.z*Common.Utils.Math.hypot(si1, si2)}/#{Common.Utils.Math.hypot(q.x, q.y)}")
      chi_q = :math.atan2(q.y, q.x)
      chi_q = if ((chi_q - course) < -:math.pi), do: chi_q + @two_pi, else: chi_q
      chi_q = if ((chi_q - course) > :math.pi), do: chi_q - @two_pi, else: chi_q
      sin_chi_q = :math.sin(chi_q)
      cos_chi_q = :math.cos(chi_q)
      # e_px = cos_chi_q*dx + sin_chi_q*dy
      e_py = -sin_chi_q*dx + cos_chi_q*dy
      course_cmd = chi_q - path_follower.chi_inf_over_two_pi*:math.atan(path_follower.k_path*e_py)
      |> Common.Utils.constrain_angle_to_compass()

      {path_case.v_des, course_cmd, altitude_cmd}
    else
      altitude_cmd = path_case.c.altitude

      {dx, dy} = Common.Utils.Location.dx_dy_between_points(path_case.c, position)
      orbit_d = Common.Utils.Math.hypot(dx, dy)
      phi = :math.atan2(dy, dx)
      phi = if ((phi - course) < -:math.pi), do: phi + @two_pi, else: phi
      phi = if ((phi - course) > :math.pi), do: phi - @two_pi, else: phi
      course_cmd = phi + path_case.turn_direction*(@pi_2 + :math.atan(path_follower.k_orbit*(orbit_d - path_case.rho)/path_case.rho))
      |> Common.Utils.constrain_angle_to_compass()

      # e_py = orbit_d - path_case.rho

      {path_case.v_des, course_cmd, altitude_cmd}
    end
  end
end
