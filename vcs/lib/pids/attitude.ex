defmodule Pids.Attitude do
  require Logger

  @spec calculate_outputs(map(), map(), float(), float()) :: map()
  def calculate_outputs(cmds, values, airspeed, dt) do
    rollrate_output = Pids.Pid.update_pid(:roll, :rollrate, cmds.roll, values.roll, airspeed, dt)
    pitchrate_output = Pids.Pid.update_pid(:pitch, :pitchrate, cmds.pitch, values.pitch, airspeed, dt)
    # Logger.debug("att cmds: #{inspect(cmds)}")
    yawrate_output =
    if Map.has_key?(cmds, :yaw) do
      Pids.Pid.update_pid(:yaw, :yawrate, cmds.yaw, 0.0, airspeed, dt)
    else
      cmd = cmds.roll*0.1
      Pids.Pid.force_output(:yaw, :yawrate, cmd)
      cmd
    end
    thrust_output = cmds.thrust
    output_str =
      Common.Utils.eftb(rollrate_output,2) <> "/" <>
      Common.Utils.eftb(pitchrate_output,2) <> "/" <>
      Common.Utils.eftb(thrust_output,2) <> "/" <>
      Common.Utils.eftb(yawrate_output, 2)
    # Logger.debug("attitude output: RR/PR/thr/YR: #{output_str}")
    %{rollrate: rollrate_output, pitchrate: pitchrate_output, yawrate: yawrate_output, thrust: thrust_output}
  end

end
