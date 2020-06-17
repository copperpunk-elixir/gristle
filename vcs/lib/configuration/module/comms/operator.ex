defmodule Configuration.Module.Comms.Operator do
  @spec get_config(atom(), atom()) :: map()
  def get_config(name, _node_type) do
    %{
      operator: %{
        name: name,
        refresh_groups_loop_interval_ms: 100
      }
    }
  end
end
