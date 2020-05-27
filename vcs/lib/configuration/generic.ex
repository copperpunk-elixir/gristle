defmodule Configuration.Generic do

  @spec get_estimator_config() :: map()
  def get_estimator_config() do
    %{estimator:
      %{
        imu_loop_interval_ms: 50,
        imu_loop_timeout_ms: 1000,
        ins_loop_interval_ms: 100,
        ins_loop_timeout_ms: 2000,
        telemetry_loop_interval_ms: 1000,
      }}
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    [
      %{
        name: {:hb, :node},
        default_message_behavior: :default_value,
        default_value: :nil,
        value_type: :map
      },
      %{
        name: :estimator_health,
        default_message_behavior: :default_value,
        default_value: 0,
        value_type: :number
      }
    ]
  end
end
