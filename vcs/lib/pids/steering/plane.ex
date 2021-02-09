defmodule Pids.Steering.Plane do
  require Logger
  @roll_min -0.52
  @roll_max 0.52

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do

    # Logger.debug("course cmds: #{inspect(cmds)}")
    # roll_yaw_output =
    # if Map.has_key?(cmds, :course_ground) do
      # course_rotate_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_rotate - values.course)
      yaw_rotate_cmd = Pids.Pid.update_pid(:course_rotate, :yaw, cmds.course_rotate, 0.0, airspeed, dt)
      # %{roll: 0.0, yaw: yaw_cmd, course: course_cmd}
    # else
      course_tilt_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_tilt - values.course)
      # |> Common.Utils.Math.constrain(-@roll_max, @roll_max)
      # Logger.debug("course cmd: #{Common.Utils.eftb_deg(course_cmd,1)}")
      roll_cmd = Pids.Pid.update_pid(:course_tilt, :roll, Common.Utils.Math.constrain(course_tilt_cmd, @roll_min, @roll_max), 0.0, airspeed, dt)
      # Logger.debug("crs/roll: #{Common.Utils.eftb_deg(course_tilt_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
      yaw_tilt_cmd = 0.25*course_tilt_cmd
      # Logger.debug("yaw tilt/rotate: #{Common.Utils.eftb(yaw_tilt_cmd, 2)}/#{Common.Utils.eftb(yaw_rotate_cmd, 2)}")
      %{roll: roll_cmd, yaw: yaw_rotate_cmd+yaw_tilt_cmd, course: course_tilt_cmd}
    # end
    # roll_yaw_output
  end

end
