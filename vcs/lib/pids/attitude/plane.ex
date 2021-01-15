defmodule Pids.Attitude.Plane do
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
      cmds.roll*0.2
    end
    thrust_output = cmds.thrust
    # output_str =
    #   Common.Utils.eftb_deg(rollrate_output,2) <> "/" <>
    #   Common.Utils.eftb_deg(pitchrate_output,2) <> "/" <>
    #   Common.Utils.eftb(thrust_output,2) <> "/" <>
    #   Common.Utils.eftb_deg(yawrate_output, 2)
    # Logger.debug("attitude output: RR/PR/thr/YR: #{output_str}")
    # unless is_nil(cmds.roll) or is_nil(values.roll) do
      # Logger.debug("roll cmd/act: #{Common.Utils.eftb_deg(cmds.roll,1)}/#{Common.Utils.eftb_deg(values.roll,1)}")
      # Logger.debug("pitch cmd/act: #{Common.Utils.eftb_deg(cmds.pitch,1)}/#{Common.Utils.eftb_deg(values.pitch,1)}")
    # Logger.debug("pitch cmd/act/err: #{Common.Utils.eftb_deg(cmds.pitch,1)}/#{Common.Utils.eftb_deg(values.pitch,1)}/#{Common.Utils.eftb_deg(cmds.pitch-values.pitch,1)}")
    # end
    %{rollrate: rollrate_output, pitchrate: pitchrate_output, yawrate: yawrate_output, thrust: thrust_output}
  end

  @spec get_output_in_range(float(), float(), map()) :: float()
  def get_output_in_range(cmd, value, config) do
    # Logger.debug("cmd/value/scaled: #{Common.Utils.eftb_deg(cmd,1)}/#{Common.Utils.eftb_deg(value,1)}/#{Common.Utils.eftb(config.scale*(cmd-value),3)}")
    config.scale*(cmd-value) + config.output_neutral
    |> Common.Utils.Math.constrain(config.output_min, config.output_max)
  end

end
