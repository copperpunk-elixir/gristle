defmodule Configuration.Module.MessageSorter do

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    [
      sorter_configs: get_sorter_configs(model_type)
    ]
  end


  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)

    vehicle_modules = [Control, Navigation]
    generic_modules = [Actuation, Cluster]

    vehicle_sorter_configs =
      Enum.reduce(vehicle_modules, [], fn (module, acc) ->
        module = Module.concat(Configuration.Module, module)
        Enum.concat(acc,apply(module, :get_sorter_configs,[vehicle_type]))
      end)

    module_sorter_configs =
      Enum.reduce(generic_modules, [], fn (module, acc) ->
        module = Module.concat(Configuration.Module, module)
        Enum.concat(acc,apply(module, :get_sorter_configs,[model_type]))
      end)

    vehicle_sorter_configs ++ module_sorter_configs
  end
end
