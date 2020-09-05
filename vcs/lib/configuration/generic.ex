defmodule Configuration.Generic do
  require Logger

  @spec get_loop_interval_ms(atom()) :: integer()
  def get_loop_interval_ms(loop_type) do
    case loop_type do
      :super_fast -> 5
      :fast -> 20
      :medium -> 100
      :slow -> 200
    end
  end

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    Logger.warn("sender: #{inspect(sender)}")
    classification_all = %{
      :actuator_cmds => %{
        Pids.Moderator => [0,1],
        # Navigation.Navigator => [0,2]
      },
      :pv_cmds => %{
        Pids.Moderator => [0,1],
        Navigation.Navigator => [0,2]
      },
      :goals => %{
        Command.Commander => [0,1],
        Navigation.PathManager => [0,2]
      },
      :control_state => %{
        Navigation.Navigator => [0,1]
      }
    }

    time_validity_all = %{
      {:hb, :node} => 500,
      :actuator_cmds => 200,
      :pv_cmds => 300,
      :goals => 300,
      :control_state => 200
    }

    classification =
      Map.get(classification_all, sorter, %{})
      |> Map.get(sender, nil)
    time_validity = Map.get(time_validity_all, sorter, 0)
    Logger.warn("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end
end
