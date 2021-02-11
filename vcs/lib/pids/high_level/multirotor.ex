defmodule Pids.HighLevel.Multirotor do
  @spec calculate_outputs(map(), map(), float()) :: map()
  def calculate_outputs(cmds, values, dt) do
    thrust = Pids.Tecs.Multirotor.calculate_outputs(cmds, values, dt)
    roll_pitch_yaw_course = Pids.Steering.Multirotor.calculate_outputs(cmds, values, dt)
    Map.put(roll_pitch_yaw_course, :thrust, thrust)
  end
end
