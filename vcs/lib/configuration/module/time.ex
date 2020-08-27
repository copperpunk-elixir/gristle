defmodule Configuration.Module.Time do
  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      server: get_server_config()
    }
  end
  def get_server_config() do
    %{
      server_loop_interval_ms: 1_000
    }
  end
end
