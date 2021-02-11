defmodule Pids.Tecs.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float()) :: map()
  def calculate_outputs(cmds, values, dt) do
    thrust = Pids.Pid.update_pid(:tecs, :thrust, cmds.speed, values.speed, values.speed, dt)
    brake =
    if thrust > 0.01 and (values.speed - cmds.speed) < 5.0 do
      0
    else
      Pids.Pid.update_pid(:tecs, :brake, cmds.speed, values.speed, values.speed, dt)
    end
    %{thrust: thrust, brake: brake}
  end
end
