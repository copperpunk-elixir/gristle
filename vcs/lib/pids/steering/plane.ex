defmodule Pids.Steering.Plane do
  require Logger
  @roll_max 0.52

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do

    # Logger.debug("course cmds: #{inspect(cmds)}")
    roll_yaw_output =
    if Map.has_key?(cmds, :course_ground) do
      course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_ground - values.course)
      yaw_cmd = Pids.Pid.update_pid(:course_ground, :yaw, course_cmd, 0.0, airspeed, dt)
      %{roll: 0.0, yaw: yaw_cmd, course: course_cmd}
    else
      course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_flight - values.course)
      |> Common.Utils.Math.constrain(-@roll_max, @roll_max)
      # Logger.debug("course cmd: #{Common.Utils.eftb_deg(course_cmd,1)}")
      roll_cmd = Pids.Pid.update_pid(:course_flight, :roll, course_cmd, 0.0, airspeed, dt)
      # Logger.debug("crs/roll: #{Common.Utils.eftb_deg(course_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
      yaw_cmd = 0.5*course_cmd
      # Logger.debug("yaw cmd: #{Common.Utils.eftb(yaw_cmd, 2)}")
      %{roll: roll_cmd, yaw: yaw_cmd, course: course_cmd}
    end
    roll_yaw_output
  end

end
