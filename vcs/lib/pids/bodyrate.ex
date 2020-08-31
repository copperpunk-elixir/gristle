defmodule Pids.Bodyrate do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    aileron_output = Pids.Pid.update_pid(:rollrate, :aileron, cmds.rollrate, values.rollrate, airspeed, dt)
    elevator_output = Pids.Pid.update_pid(:pitchrate, :elevator, cmds.pitchrate, values.pitchrate, airspeed, dt)
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    throttle_output = cmds.thrust
    output_str =
      Common.Utils.eftb(aileron_output,2) <> "/" <>
      Common.Utils.eftb(elevator_output,2) <> "/" <>
      Common.Utils.eftb(throttle_output,2) <> "/" <>
      Common.Utils.eftb(rudder_output, 2)
    # Logger.debug("bodyrate output: ail/elev/thr/rud: #{output_str}")
    %{aileron: aileron_output, elevator: elevator_output, rudder: rudder_output, throttle: throttle_output}
  end

end
