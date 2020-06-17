defmodule Configuration.Module.MessageSorter do

  @spec get_config(atom(), atom()) :: map()
  def get_config(vehicle_type, _node_type) do
    %{
      sorter_configs: get_sorter_configs(vehicle_type)
    }
  end


  @spec get_sorter_configs(atom()) :: list()
  def get_sorter_configs(vehicle_type) do
    base_module = Configuration.Vehicle
    vehicle_modules = [Control, Navigation]
    Enum.reduce(vehicle_modules, %{}, fn (module, acc) ->
      vehicle_module =
        Module.concat(base_module, vehicle_type)
        |>Module.concat(module)
      Enum.concat(acc,apply(vehicle_module, :get_sorter_configs,[]))
    end)
    |> Enum.concat(Configuration.Module.Actuation.get_actuation_sorter_configs(vehicle_type))
    |> Enum.concat(get_generic_sorter_configs())
  end

  @spec get_generic_sorter_configs() :: list()
  def get_generic_sorter_configs() do
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
      },

    ]
  end

end