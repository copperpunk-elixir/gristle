defmodule Pids.Steering.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("course cmds: #{inspect(cmds)}")
    course_cmd = Common.Utils.Motion.turn_left_or_right_for_correction(cmds.course_rotate - values.course)
    yaw_cmd = course_cmd
    %{yaw: yaw_cmd, course: course_cmd}
  end

end
