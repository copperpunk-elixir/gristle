defmodule Configuration.Module.Telemetry do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    Logger.info("Telemetry node type: #{node_type}")
    %{
      operator:
      %{
        device_description: "FT231X",
        fast_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        medium_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      }
    }
  end
end
