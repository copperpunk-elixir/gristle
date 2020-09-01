defmodule Pids.Attitude do
  require Logger

  @spec calculate_outputs(map(), map(), map()) :: map()
  def calculate_outputs(cmds, values, config) do
    rollrate_output = get_output_in_range(cmds.roll, values.roll, config.roll_rollrate)
    pitchrate_output = get_output_in_range(cmds.pitch, values.pitch, config.pitch_pitchrate)
    # Logger.debug("att cmds: #{inspect(cmds)}")
    yawrate_output =
    if Map.has_key?(cmds, :yaw) do
      get_output_in_range(cmds.yaw, 0.0, config.yaw_yawrate)
    else
      cmds.roll*0.1
    end
    thrust_output = cmds.thrust
    # output_str =
    #   Common.Utils.eftb_deg(rollrate_output,2) <> "/" <>
    #   Common.Utils.eftb_deg(pitchrate_output,2) <> "/" <>
    #   Common.Utils.eftb(thrust_output,2) <> "/" <>
    #   Common.Utils.eftb_deg(yawrate_output, 2)
    # Logger.debug("attitude output: RR/PR/thr/YR: #{output_str}")
    %{rollrate: rollrate_output, pitchrate: pitchrate_output, yawrate: yawrate_output, thrust: thrust_output}
  end

  @spec get_output_in_range(float(), float(), map()) :: float()
  def get_output_in_range(cmd, value, config) do
    config.scale*(cmd-value) + config.output_neutral
    |> Common.Utils.Math.constrain(config.output_min, config.output_max)
  end
end
