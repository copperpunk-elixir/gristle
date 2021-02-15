defmodule Configuration.MessageSorter do
  def get_config(_node_type) do
    [
      sorter_configs: get_sorter_configs()
    ]
  end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    generic_modules = [Cluster, Uart]

    Enum.reduce(generic_modules, [], fn (module, acc) ->
      module = Module.concat(Configuration, module)
      Enum.concat(acc,apply(module, :get_sorter_configs,[]))
    end)
  end

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    # Logger.debug("sender: #{inspect(sender)}")
    classification_all = %{
      {:hb, :node} => %{
        Cluster.Heartbeat => [1,1]
      },
      :servo_output => %{
        Uart.Operator => [1, :random.uniform(10000)]
      }
    }

    time_validity =
    case sorter do
      {:hb, :node} -> 500
      :servo_output -> 200
      _other -> 0
    end

    classification =
      Map.get(classification_all, sorter, %{})
      |> Map.get(sender, nil)
    # time_validity = Map.get(time_validity_all, sorter, 0)
    # Logger.debug("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end

end
