defmodule Configuration.Module.Telemetry do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      operator: %{device_description: "FT230X"}
    }
  end
end
