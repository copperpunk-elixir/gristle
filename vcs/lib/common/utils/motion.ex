defmodule Common.Utils.Motion do
  require Logger

  # Convert North/East velocity to Speed/Course
  @spec get_speed_course_for_velocity(number(), number(), number(), number()) :: float()
  def get_speed_course_for_velocity(v_north, v_east, min_speed_for_course, yaw) do
    speed = Common.Utils.Math.hypot(v_north, v_east)
    course =
    if speed >= min_speed_for_course do
      :math.atan2(v_east, v_north)
      |> constrain_angle_to_compass()
    else
      yaw
    end
    {speed, course}
  end

  @spec adjust_velocity_for_min_speed(map(), number(), number()) :: map()
    def adjust_velocity_for_min_speed(velocity, min_speed_for_course, yaw) do
    speed = Common.Utils.Math.hypot(velocity.north, velocity.east)
    if (speed >= min_speed_for_course) do
      velocity
    else
      %{velocity | north: speed*:math.cos(yaw), east: speed*:math.sin(yaw)}
    end
  end

  # Turn correctly left or right using delta Yaw/Course
  @spec turn_left_or_right_for_correction(number()) :: number()
  def turn_left_or_right_for_correction(correction) do
    cond do
      correction < -:math.pi() -> correction + 2.0*:math.pi()
      correction > :math.pi() -> correction - 2.0*:math.pi()
      true -> correction
    end
  end

  @spec constrain_angle_to_compass(number()) :: number()
  def constrain_angle_to_compass(angle) do
    cond do
      angle < 0.0 -> angle + 2.0*:math.pi()
      angle >= 2.0*:math.pi() -> angle - 2.0*:math.pi()
      true -> angle
    end
  end

  @spec angle_between_points(struct(), struct()) :: float()
  def angle_between_points(lla_1, lla_2) do
    {dx, dy} = Common.Utils.Location.dx_dy_between_points(lla_1, lla_2)
    constrain_angle_to_compass(:math.atan2(dy, dx))
  end

  @spec attitude_to_accel(map()) :: map()
  def attitude_to_accel(attitude) do
    cos_theta = :math.cos(attitude.pitch)

    ax = -:math.sin(attitude.pitch)
    ay = :math.sin(attitude.roll)*cos_theta
    az = :math.cos(attitude.roll)*cos_theta
    %{x: ax*Common.Constants.gravity(), y: ay*Common.Constants.gravity(), z: az*Common.Constants.gravity()}
  end

  @spec inertial_to_body_euler(map(), tuple()) :: tuple()
  def inertial_to_body_euler(attitude, vector) do
    cosphi = :math.cos(attitude.roll)
    sinphi = :math.sin(attitude.roll)
    costheta = :math.cos(attitude.pitch)
    sintheta = :math.sin(attitude.pitch)
    cospsi = :math.cos(attitude.yaw)
    sinpsi = :math.sin(attitude.yaw)

    {vx,vy,vz} = vector

    bx = costheta*cospsi*vx + costheta*sinpsi*vy - sintheta*vz
    by = (-cosphi*sinpsi + sinphi*sintheta*cospsi)*vx + (cosphi*cospsi + sinphi*sintheta*sinpsi)*vy + sinphi*costheta*vz
    bz = (sinphi*sinpsi + cosphi*sintheta*cospsi)*vx - (sinphi*cospsi + cosphi*sintheta*sinpsi)*vy + cosphi*costheta*vz
    {bx,by,bz}
  end
end
