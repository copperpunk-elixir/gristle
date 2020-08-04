defmodule Configuration.Module.Telemetry do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      operator:
      %{
        device_description: "FT230X",
        fast_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        medium_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
      }
    }
  end
end
