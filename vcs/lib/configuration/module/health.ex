defmodule Configuration.Module.Health do
  @spec get_config(atom(), atom()) :: map()
  def get_config(model_type, _node_type) do
    watchdogs =
      case model_type do
        :Cessna -> [:motor, :cluster]
        :T28 -> [:motor, :cluster]
        :T28Z2m -> [:motor, :cluster]
      end
    %{
      power: %{
        status_loop_interval_ms: 1000,
        watchdogs: watchdogs,
        watchdog_interval_ms: 1000
      }
    }
  end
end
