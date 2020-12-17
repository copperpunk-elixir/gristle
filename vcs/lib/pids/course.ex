defmodule Pids.Course do
  require Logger
  @roll_max 0.52

  @spec calculate_outputs(map(), float(), float()) :: map()
  def calculate_outputs(cmds, airspeed, dt) do
    # Logger.debug("course cmds: #{inspect(cmds)}")
    roll_yaw_output =
    if Map.has_key?(cmds, :course_ground) do
      yaw_cmd = Pids.Pid.update_pid(:course_ground, :yaw, cmds.course_ground, 0.0, airspeed, dt)
      %{roll: 0.0, yaw: yaw_cmd}
    else
      course_cmd = Common.Utils.Math.constrain(cmds.course_flight,-@roll_max, @roll_max)
      # Logger.debug("course cmd: #{Common.Utils.eftb_deg(course_cmd,1)}")
      roll_cmd = Pids.Pid.update_pid(:course_flight, :roll, course_cmd, 0.0, airspeed, dt)
      # Logger.debug("crs/roll: #{Common.Utils.eftb_deg(course_cmd,1)}/#{Common.Utils.eftb_deg(roll_cmd,1)}")
      yaw_cmd = 0.25*cmds.course_flight
      %{roll: roll_cmd, yaw: yaw_cmd}
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
