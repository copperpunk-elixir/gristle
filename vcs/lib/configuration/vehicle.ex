defmodule Configuration.Vehicle do
  require Logger

  @spec get_sorter_configs(atom()) :: list()
  def get_sorter_configs(vehicle_type) do
    base_module = Configuration.Vehicle
    vehicle_modules = [Actuation, Control, Navigation]
    sorter_configs = Enum.reduce(vehicle_modules, %{}, fn (module, acc) ->
      vehicle_module =
        Module.concat(base_module, vehicle_type)
        |>Module.concat(module)
      Enum.concat(acc,apply(vehicle_module, :get_sorter_configs,[]))
    end)
  end
end

