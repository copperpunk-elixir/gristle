defmodule Configuration.Module.Control do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      controller: [
        process_variable_cmd_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast)
      ]
    ]
  end
end
