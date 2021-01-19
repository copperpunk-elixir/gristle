defmodule Pids.HighLevel.Plane do
  @spec calculate_outputs(map(), map(), float, float) :: map()
  def calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt) do
    # Calculate tilt-angle based on speed requirement
    thrust_and_pitch = Pids.Tecs.Plane.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
    # Calculate roll, pitch, yaw, based on tilt output and course
    roll_yaw_course = Pids.Steering.Plane.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
    Map.merge(thrust_and_pitch, roll_yaw_course)
  end
end
