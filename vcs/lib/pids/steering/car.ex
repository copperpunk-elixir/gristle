defmodule Pids.Steering.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, _values, _airspeed, _dt) do
    # Logger.debug("course cmds: #{inspect(cmds)}")
    course_cmd = cmds.course_rotate
    # Logger.debug("#{Common.Utils.eftb_deg(cmds.course_rotate, 1)}/#{Common.Utils.eftb_deg(course_cmd, 1)}")
    %{yaw: course_cmd, course: course_cmd}
  end

end
