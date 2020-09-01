defmodule Pids.Tecs do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    Logger.debug("tecs cmds: #{inspect(cmds)}")
    thrust_output = Pids.Pid.update_pid(:tecs, :thrust, cmds, values, airspeed, dt)
    pitch_output = Pids.Pid.update_pid(:tecs, :pitch, cmds, values, airspeed, dt)

    %{pitch: pitch_output, thrust: thrust_output}
  end
end
