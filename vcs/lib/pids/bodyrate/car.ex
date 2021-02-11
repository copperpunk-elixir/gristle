defmodule Pids.Bodyrate.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float(), map()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt, _ignore) do
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, airspeed, dt)
    %{rudder: rudder_output, throttle: cmds.thrust, brake: cmds.brake}
  end

end
