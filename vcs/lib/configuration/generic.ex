defmodule Configuration.Generic do
  require Logger

  @spec get_loop_interval_ms(atom()) :: integer()
  def get_loop_interval_ms(loop_type) do
    case loop_type do
      :super_fast -> 5
      :fast -> 20
      :medium -> 100
      :slow -> 200
      :extra_slow -> 1000
    end
  end

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    Logger.debug("sender: #{inspect(sender)}")
    classification_all = %{
      {:hb, :node} => %{
        Cluster.Heartbeat => [0,1]
      },
      :indirect_actuator_cmds => %{
        Pids.Moderator => [0,1],
        # Navigation.Navigator => [0,2]
      },
      :indirect_override_cmds => %{
        Command.Commander => [0,1],
        # Navigation.PathManager => [0,2]
      },
      {:direct_actuator_cmds, :flaps} => %{
        Command.Commander => [0,1],
        Navigation.PathManager => [0,2]
      },
      {:direct_actuator_cmds, :gear} => %{
        Command.Commander => [0,1],
        Navigation.PathManager => [0,2]
      },
      {:direct_actuator_cmds, :all} => %{
        Command.Commander => [0,1],
      },
      # {:direct_actuator_cmds, :select} => %{
      #   Command.Commander => [0,1],
      #   Pids.Moderator => [0,2]
      # },
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

    time_validity =
    case sorter do
      {:hb, :node} -> 500
      :indirect_actuator_cmds -> 200
      :indirect_override_cmds -> 200
      {:direct_actuator_cmds, _} -> 200
      # :actuation_selector -> 200
      :pv_cmds -> 300
      :goals -> 300
      :control_state -> 200
      _other -> 0
    end

    classification =
      Map.get(classification_all, sorter, %{})
      |> Map.get(sender, nil)
    # time_validity = Map.get(time_validity_all, sorter, 0)
    Logger.debug("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end
end
