defmodule Pids.Steering.Multirotor do
  require Logger
  @yaw_max 0.78
  @min_speed_for_course 1.0

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("course cmds: #{inspect(cmds)}")
    # Logger.debug("tilt: #{Common.Utils.eftb_deg(tilt_cmd, 2)}")
    # Logger.debug("cmds: #{Common.Utils.eftb_map_deg(cmds, 2)}")
    # Logger.debug("vals: #{Common.Utils.eftb_map_deg(values, 2)}")
    # rotation_yaw_to_course = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_flight - values.yaw)
    # tilt_cmd = cmds.tilt*get_tilt_direction(rotation_yaw_to_course)
    # Logger.debug("rytc: #{Common.Utils.eftb_deg(rotation_yaw_to_course, 2)}")
    course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_flight - values.course)
    # course_cmd = 0
    # cmds = %{cmds | course_flight: 0}
    vN_cmd = cmds.speed*:math.cos(cmds.course_flight)
    vE_cmd = cmds.speed*:math.sin(cmds.course_flight)
    vN = values.speed*:math.cos(values.course)
    vE = values.speed*:math.sin(values.course)

    vx_cmd = vN_cmd*:math.cos(-values.yaw) - vE_cmd*:math.sin(-values.yaw)#  cmds.speed*:math.cos(actual_yaw_to_course)
    vy_cmd = vN_cmd*:math.sin(-values.yaw) + vE_cmd*:math.cos(-values.yaw)#cmds.speed*:math.sin(actual_yaw_to_course)
    vx = vN*:math.cos(-values.yaw) - vE*:math.sin(-values.yaw)
    vy = vN*:math.sin(-values.yaw) + vE*:math.cos(-values.yaw)
    # Logger.info("vN_cmd/vE_cmd: #{Common.Utils.eftb(vN_cmd, 2)}/#{Common.Utils.eftb(vE_cmd, 2)}")
    # Logger.info("vxcmd/vycmd: #{Common.Utils.eftb(vx_cmd, 2)}/#{Common.Utils.eftb(vy_cmd, 2)}")
    # Logger.info("vx/vy: #{Common.Utils.eftb(vx, 2)}/#{Common.Utils.eftb(vy, 2)}")
    pitch_cmd = -Pids.Pid.update_pid(:tecs, :pitch, vx_cmd, vx, airspeed, dt)
    roll_cmd = Pids.Pid.update_pid(:tecs, :roll, vy_cmd, vy, airspeed, dt)
    # roll_yaw_output =
      # Logger.debug("course cmd-pre: #{Common.Utils.eftb_deg(cmds.course_flight,1)}")
    {yaw_cmd, course_cmd} =
    if values.speed > @min_speed_for_course do
      dyaw = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.yaw_offset + values.course - values.yaw)
      |> Common.Utils.Math.constrain(-@yaw_max, @yaw_max)
      # goal_yaw = Common.Utils.Motion.constrain_angle_to_compass(values.yaw + dyaw)
      # Logger.debug("goal yaw/ act yaw: #{Common.Utils.eftb_deg(goal_yaw, 2)}/#{Common.Utils.eftb_deg(values.yaw, 2)}")
      # yaw_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(goal_yaw - values.yaw)
      # Logger.debug("yaw cmd: #{Common.Utils.eftb_deg(yaw_cmd, 2)}")
      # |> Kernel.+(cmds.yaw_offset)
      {dyaw, course_cmd}
    else
      yaw_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_flight - values.yaw)
      |> Kernel.+(cmds.yaw_offset)
      |> Common.Utils.Math.constrain(-@yaw_max, @yaw_max)
      # Logger.info("yaw cmd: #{Common.Utils.eftb_deg(yaw_cmd, 2)}")
      {yaw_cmd, yaw_cmd}
    end

    Logger.debug("course/roll: #{Common.Utils.eftb_deg(course_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
    # Logger.debug("course cmd-pst: #{Common.Utils.eftb_deg(course_cmd,1)}")
    %{roll: roll_cmd, pitch: pitch_cmd, yaw: yaw_cmd, course: course_cmd}
  end

  # def get_tilt_direction(rotation_yaw_to_course) do
  #   if :math.cos(rotation_yaw_to_course) > 0 do
  #     1
  #   else
  #     -1
  #   end
  # end
end
