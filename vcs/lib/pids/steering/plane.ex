defmodule Pids.Steering.Plane do
  require Logger
  @roll_min -0.52
  @roll_max 0.52

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("course cmds: #{inspect(cmds)}")
      yaw_rotate_cmd = cmds.course_rotate
      course_tilt_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_tilt - values.course)
      roll_cmd = Pids.Pid.update_pid(:course_tilt, :roll, Common.Utils.Math.constrain(course_tilt_cmd, @roll_min, @roll_max), 0.0, airspeed, dt)
      # Logger.debug("crs/roll: #{Common.Utils.eftb_deg(course_tilt_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
      %{roll: roll_cmd, yaw: yaw_rotate_cmd, course: course_tilt_cmd}
  end

end
