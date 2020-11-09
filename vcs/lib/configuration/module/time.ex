defmodule Configuration.Module.Time do
  @spec get_config(binary(), binary()) :: map()
  def get_config(_vehicle_type, _node_type) do
    %{
      server: get_server_config()
    }
  end
  def get_server_config() do
    %{
      server_loop_interval_ms: 10_000
    }
  end
end
