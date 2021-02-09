defmodule Pids.Steering.Multirotor do
  require Logger
  @yaw_max 0.52
  @min_speed_for_course 1.0

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_tilt - values.course)
    vN_cmd = cmds.speed*:math.cos(cmds.course_tilt)
    vE_cmd = cmds.speed*:math.sin(cmds.course_tilt)
    vN = values.speed*:math.cos(values.course)
    vE = values.speed*:math.sin(values.course)

    m_sin_yaw = :math.sin(-values.yaw)
    m_cos_yaw = :math.cos(-values.yaw)
    vx_cmd = vN_cmd*m_cos_yaw - vE_cmd*m_sin_yaw
    vy_cmd = vN_cmd*m_sin_yaw + vE_cmd*m_cos_yaw
    vx = vN*m_cos_yaw - vE*m_sin_yaw
    vy = vN*m_sin_yaw + vE*m_cos_yaw
    # Logger.info("vN_cmd/vE_cmd: #{Common.Utils.eftb(vN_cmd, 2)}/#{Common.Utils.eftb(vE_cmd, 2)}")
    # Logger.info("vxcmd/vycmd: #{Common.Utils.eftb(vx_cmd, 2)}/#{Common.Utils.eftb(vy_cmd, 2)}")
    # Logger.info("vx/vy: #{Common.Utils.eftb(vx, 2)}/#{Common.Utils.eftb(vy, 2)}")
    pitch_cmd = -Pids.Pid.update_pid(:course, :pitch, vx_cmd, vx, airspeed, dt)
    roll_cmd = Pids.Pid.update_pid(:course, :roll, vy_cmd, vy, airspeed, dt)

    {yaw_cmd, course_cmd} =
    if values.speed > @min_speed_for_course do
      dyaw = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_rotate + values.course - values.yaw)
      |> Common.Utils.Math.constrain(-@yaw_max, @yaw_max)
      {dyaw, course_cmd}
    else
      yaw_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_tilt - values.yaw)
      |> Kernel.+(cmds.course_rotate)
      |> Common.Utils.Math.constrain(-@yaw_max, @yaw_max)
      {yaw_cmd, yaw_cmd}
    end

    # Logger.debug("course/roll: #{Common.Utils.eftb_deg(course_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
    %{roll: roll_cmd, pitch: pitch_cmd, yaw: yaw_cmd, course: course_cmd}
  end

end
