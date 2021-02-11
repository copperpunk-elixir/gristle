defmodule Pids.Bodyrate.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), map()) :: map()
  def calculate_outputs(cmds, values, dt, _ignore) do
    rudder_output = Pids.Pid.update_pid(:yawrate, :rudder, cmds.yawrate, values.yawrate, values.airspeed, dt)
    %{rudder: rudder_output, throttle: cmds.thrust, brake: cmds.brake}
  end

end
