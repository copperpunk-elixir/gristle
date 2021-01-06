defmodule Configuration.Module.Health do
  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    watchdogs =
      case model_type do
        "Cessna" -> [:motor, :cluster]
        "CessnaZ2m" -> [:motor, :cluster]
        "T28" -> [:motor, :cluster]
        "T28Z2m" -> [:motor, :cluster]
      end
    [
      power: [
        status_loop_interval_ms: 1000,
        watchdogs: watchdogs,
        watchdog_interval_ms: 1000
      ]
    ]
  end
end
