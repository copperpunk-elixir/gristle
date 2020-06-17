defmodule Configuration.Module.Navigation do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      navigator: %{
        vehicle_type: vehicle_type,
        navigator_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
        default_pv_cmds_level: 3
      }}
  end
end
