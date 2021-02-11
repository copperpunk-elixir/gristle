defmodule Pids.Bodyrate.Plane do
  require Logger

  @spec calculate_outputs(map(), map(), float(), map()) :: map()
  def calculate_outputs(cmds, values, dt, _ignore) do
    aileron_output = Pids.Pid.update_pid(:rollrate, :aileron, cmds.rollrate, values.rollrate, values.airspeed, dt)
    elevator_output = Pids.Pid.update_pid(:pitchrate, :elevator, cmds.pitchrate, values.pitchrate, values.airspeed, dt)
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, values.airspeed, dt)
    # Logger.debug("pitch cmd/val: #{Common.Utils.eftb_deg(cmds.pitchrate,0)}/#{Common.Utils.eftb_deg(values.pitchrate,0)}")
    # output_str =
    #   Common.Utils.eftb(aileron_output,2) <> "/" <>
    #   Common.Utils.eftb(elevator_output,2) <> "/" <>
    #   Common.Utils.eftb(throttle_output,2) <> "/" <>
    #   Common.Utils.eftb(rudder_output, 2)
    # Logger.debug("bodyrate output: ail/elev/thr/rud: #{output_str}")
    %{aileron: aileron_output, elevator: elevator_output, rudder: rudder_output, throttle: cmds.thrust}
  end

end
