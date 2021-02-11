defmodule Pids.HighLevel.Plane do
  require Logger

  @spec calculate_outputs(map(), map(), float, float) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    # Logger.debug("HL cmds: #{inspect(cmds)}")
    thrust_and_pitch = Pids.Tecs.Plane.calculate_outputs(cmds, values, airspeed, dt)
    roll_yaw_course = Pids.Steering.Plane.calculate_outputs(cmds, values, airspeed, dt)
    Map.merge(thrust_and_pitch, roll_yaw_course)
  end
end
