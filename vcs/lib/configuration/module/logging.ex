defmodule Configuration.Module.Logging do
  @spec get_config(binary(), binary()) :: map()
  def get_config(_model_type, _node_type) do
    %{
      logger: %{
        root_path: "/mnt/"
      }
    }
  end
end
