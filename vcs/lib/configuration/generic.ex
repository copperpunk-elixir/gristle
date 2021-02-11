defmodule Configuration.Generic do
  require Logger

  @spec get_loop_interval_ms(atom()) :: integer()
  def get_loop_interval_ms(loop_type) do
    case loop_type do
      :super_fast -> 10
      :fast -> 20
      :medium -> 40
      :slow -> 200
      :extra_slow -> 1000
    end
  end

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    # Logger.debug("sender: #{inspect(sender)}")
    classification_all = %{
      {:hb, :node} => %{
        Cluster.Heartbeat => [1,1]
      },
      :indirect_actuator_cmds => %{
        Control.Controller => [1,1],
        # Navigation.Navigator => [0,2]
      },
      :indirect_override_cmds => %{
        Command.Commander => [1,1],
        # Navigation.PathManager => [0,2]
      },
      {:direct_actuator_cmds, :flaps} => %{
        Command.Commander => [1,1],
        Navigation.PathManager => [1,2]
      },
      {:direct_actuator_cmds, :gear} => %{
        Command.Commander => [1,1],
        Navigation.PathManager => [1,2]
      },
      {:direct_actuator_cmds, :all} => %{
        Command.Commander => [1,1],
      },
      # {:direct_actuator_cmds, :select} => %{
      #   Command.Commander => [0,1],
      #   Pids.Moderator => [0,2]
      # },
      :pv_cmds => %{
        Control.Controller => [1,1],
        Navigation.Navigator => [1,2]
      },
      :goals => %{
        Command.Commander => [1,1],
        Navigation.PathManager => [1,2]
      },
      :control_state => %{
        Navigation.Navigator => [1,1]
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
    # Logger.debug("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end

  @spec native_source?(list()) :: boolean()
  def native_source?(classification) do
    [primary, _secondary] = classification
    primary == 0
  end

  @spec generic_peripheral_classification(binary()) :: list()
  def generic_peripheral_classification(peripheral_type) do
    secondary_class = :random.uniform()
    possible_types = "abcde"
    max_value = Bitwise.<<<(1, String.length(possible_types))
    primary_class = Enum.reduce(String.graphemes(String.downcase(peripheral_type)),max_value , fn (letter, acc) ->
      case :binary.match(possible_types, letter) do
        :nomatch -> acc
        {location, _} -> acc - Bitwise.<<<(1,location)
      end
     end)
    [primary_class, secondary_class]
  end
end
