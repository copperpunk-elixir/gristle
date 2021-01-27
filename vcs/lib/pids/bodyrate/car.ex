defmodule Pids.Bodyrate.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float(), map()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt, _ignore) do
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    throttle_output = cmds.thrust
    # output_str =
    #   Common.Utils.eftb(throttle_output,2) <> "/" <>
    #   Common.Utils.eftb(rudder_output, 2)
    # Logger.debug("bodyrate output: thr/rud: #{output_str}")
    # Logger.debug("yaw cmd/act: #{Common.Utils.eftb_deg(cmds.yawrate,1)}/#{Common.Utils.eftb_deg(values.yawrate,1)}")
    %{rudder: rudder_output, throttle: throttle_output}
  end

end
