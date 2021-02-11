defmodule Pids.HighLevel.Car do
  @spec calculate_outputs(map(), map(), float, float) :: map()
  def calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt) do
    thrust_brake = Pids.Tecs.Car.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
    course_yaw = Pids.Steering.Car.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
    Map.merge(course_yaw, thrust_brake)
  end
end
