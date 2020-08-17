defmodule Configuration.Module.Telemetry do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    Logger.info("Telemetry node type: #{node_type}")
    device_description =
      case node_type do
        :sim -> "USB Serial"
        _other -> "FT230X"
      end
    %{
      operator:
      %{
        device_description: device_description,
        fast_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        medium_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      }
    }
  end
end
