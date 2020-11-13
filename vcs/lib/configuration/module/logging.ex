defmodule Configuration.Module.Logging do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      logger: [
        root_path: Common.Utils.File.get_mount_path() <>  "/"
      ]
    ]
  end
end
