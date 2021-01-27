defmodule Pids.Tecs.Car do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    Pids.Pid.update_pid(:tecs, :thrust, cmds.speed, values.speed, values.speed, dt)
  end
end
