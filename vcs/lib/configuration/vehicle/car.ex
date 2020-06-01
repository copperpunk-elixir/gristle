defmodule Configuration.Vehicle.Car do
  require Logger

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    Configuration.Vehicle.Car.Actuation.get_sorter_configs()
    |> Enum.concat(Configuration.Vehicle.Car.Control.get_sorter_configs())
    |> Enum.concat(Configuration.Vehicle.Car.Navigation.get_sorter_configs())
  end

end
