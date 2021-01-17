defmodule Pids.Course.Multirotor do
  require Logger
  @yaw_max 0.52

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("course cmds: #{inspect(cmds)}")
    roll_yaw_output =
    if Map.has_key?(cmds, :course_ground) do
      # yaw_cmd = Pids.Pid.update_pid(:course_ground, :yaw, cmds.course_ground, 0.0, airspeed, dt)
      course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_ground - values.yaw)
      %{roll: 0.0, yaw: course_cmd, course: course_cmd}
    else
      # Logger.debug("course cmd-pre: #{Common.Utils.eftb_deg(cmds.course_flight,1)}")
      # Logger.debug("course cmd-yaw: #{Common.Utils.eftb_deg(values.yaw,1)}")
      course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_flight - values.yaw)
      |> Common.Utils.Math.constrain(-@yaw_max, @yaw_max)
      # Logger.debug("course cmd-pst: #{Common.Utils.eftb_deg(course_cmd,1)}")
      # yaw_cmd =  Pids.Pid.update_pid(:course_flight, :yaw, course_cmd, 0.0, airspeed, dt)
      # Logger.debug("crs/roll: #{Common.Utils.eftb_deg(course_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
      # roll_cmd = 0.25*cmds.course_flight
      roll_cmd = 0.4*course_cmd*:math.sqrt(airspeed)
      %{roll: roll_cmd, yaw: course_cmd, course: course_cmd}
    end
    # output_str = Common.Utils.eftb_deg(roll_yaw_output.roll,2)
    # output_str =
    # if Map.has_key?(roll_yaw_output, :yaw) do
    #   output_str <> "/" <> Common.Utils.eftb_deg(roll_yaw_output.yaw,2)
    # else
    #   output_str
    # end
    # Logger.debug("course output: roll/(yaw): #{output_str}")
    roll_yaw_output
  end

end
