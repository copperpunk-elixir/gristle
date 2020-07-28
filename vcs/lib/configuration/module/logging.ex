defmodule Configuration.Module.Logging do
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, _node_type) do
    %{
      logger: %{
        root_path: "/mnt/"
      }
    }
  end
end
