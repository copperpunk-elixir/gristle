defmodule Pids.HighLevel.Car do
  @spec calculate_outputs(map(), map(), float) :: map()
  def calculate_outputs(cmds, values, dt) do
    thrust_brake = Pids.Tecs.Car.calculate_outputs(cmds, values,  dt)
    course_yaw = Pids.Steering.Car.calculate_outputs(cmds, values, dt)
    Map.merge(course_yaw, thrust_brake)
  end
end
