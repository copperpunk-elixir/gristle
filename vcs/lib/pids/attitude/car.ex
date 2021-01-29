defmodule Pids.Attitude.Car do
  require Logger

  @spec calculate_outputs(map(), map(), map()) :: map()
  def calculate_outputs(cmds, _values, config) do
    yawrate_output = get_output_in_range(cmds.yaw, 0.0, config.yaw_yawrate)
    %{yawrate: yawrate_output, thrust: cmds.thrust, brake: cmds.brake}
  end

  @spec get_output_in_range(float(), float(), map()) :: float()
  def get_output_in_range(cmd, value, config) do
    # Logger.debug("cmd/value/scaled: #{Common.Utils.eftb_deg(cmd,1)}/#{Common.Utils.eftb_deg(value,1)}/#{Common.Utils.eftb(config.scale*(cmd-value),3)}")
    config.scale*(cmd-value) + config.output_neutral
    |> Common.Utils.Math.constrain(config.output_min, config.output_max)
  end

end
