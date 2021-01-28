defmodule Pids.Bodyrate.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float(), map()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt, _ignore) do
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    output_str =
      Common.Utils.eftb(cmds.thrust,2) <> "/" <>
      Common.Utils.eftb(cmds.brake, 2)
    # Logger.debug("thr/brake: #{output_str}")
    # Logger.debug("yaw cmd/act: #{Common.Utils.eftb_deg(cmds.yawrate,1)}/#{Common.Utils.eftb_deg(values.yawrate,1)}")
    %{rudder: rudder_output, throttle: cmds.thrust, brake: cmds.brake}
  end

end
