defmodule Configuration.Module.Control do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      controller: []
    ]
  end
end
