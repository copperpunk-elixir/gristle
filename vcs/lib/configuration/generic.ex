defmodule Configuration.Generic do
  require Logger

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

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    Logger.warn("sender: #{inspect(sender)}")
    classification_all = %{
      :actuator_cmds => %{
        Pids.System => [0,1]
      },
      :pv_cmds => %{
        Pids.System => [0,1]
      },
      :rx_output => %{
        Command.Commander => [0,1]
      }
    }

    time_validity_all = %{
      {:hb, :node} => 500,
      :actuator_cmds => 200,
      :pv_cmds => 200,
      :rx_output => 100
    }

    classification =
      Map.get(classification_all, sorter, %{})
      |> Map.get(sender, nil)
    time_validity = Map.get(time_validity_all, sorter, 0)
    Logger.warn("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end
end
