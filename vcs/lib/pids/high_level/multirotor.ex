defmodule Pids.HighLevel.Multirotor do
  @spec calculate_outputs(map(), map(), float, float) :: map()
  def calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt) do
    thrust = Pids.Tecs.Multirotor.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
    roll_pitch_yaw_course = Pids.Steering.Multirotor.calculate_outputs(pv_cmd_map, pv_value_map, airspeed, dt)
    Map.put(roll_pitch_yaw_course, :thrust, thrust)
  end
end
