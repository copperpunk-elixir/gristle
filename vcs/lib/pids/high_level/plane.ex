defmodule Pids.HighLevel.Plane do
  require Logger

  @spec calculate_outputs(map(), map(), float) :: map()
  def calculate_outputs(cmds, values, dt) do
    # Logger.debug("HL cmds: #{inspect(cmds)}")
    thrust_and_pitch = Pids.Tecs.Plane.calculate_outputs(cmds, values, dt)
    roll_yaw_course = Pids.Steering.Plane.calculate_outputs(cmds, values, dt)
    Map.merge(thrust_and_pitch, roll_yaw_course)
  end
end
