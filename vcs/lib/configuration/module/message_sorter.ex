defmodule Configuration.Module.MessageSorter do

  @spec get_config(binary(), binary()) :: map()
  def get_config(model_type, _node_type) do
    %{
      sorter_configs: get_sorter_configs(model_type)
    }
  end


  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    base_module = Configuration.Vehicle
    vehicle_modules = [Control, Navigation]
    Enum.reduce(vehicle_modules, %{}, fn (module, acc) ->
      vehicle_module =
        Module.concat(base_module, String.to_existing_atom(vehicle_type))
        |>Module.concat(module)
      Enum.concat(acc,apply(vehicle_module, :get_sorter_configs,[]))
    end)
    |> Enum.concat(Configuration.Module.Actuation.get_actuation_sorter_configs(model_type))
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
