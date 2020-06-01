defmodule Configuration.Vehicle.Plane do
  require Logger

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    Configuration.Vehicle.Plane.Actuation.get_sorter_configs()
    |> Enum.concat(Configuration.Vehicle.Plane.Control.get_sorter_configs())
    |> Enum.concat(Configuration.Vehicle.Plane.Navigation.get_sorter_configs())
  end
end

