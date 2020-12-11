defmodule Configuration.Module.Gcs do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      gcs: []
    ]
  end
end
