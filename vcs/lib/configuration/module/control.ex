defmodule Configuration.Module.Control do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      controller: %{
        vehicle_type: vehicle_type,
        process_variable_cmd_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium)
      }}
  end
end
