defmodule MessageSorter.System do
  # use DynamicSupervisor
  use Supervisor
  require Logger

  def start_link(vehicle_type) do
    Logger.debug("Start MessageSorter Supervisor")
    Common.Utils.start_link_redudant(Supervisor, __MODULE__, vehicle_type, __MODULE__)
  end

  @impl true
  def init(vehicle_type) do
    children = get_all_children(vehicle_type)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_all_children(vehicle_type) do
    generic_sorters = Configuration.Generic.get_sorter_configs()
    vehicle_sorters = Configuration.Vehicle.get_sorter_configs(vehicle_type)
    sorter_configs = generic_sorters ++ vehicle_sorters
    Enum.reduce(sorter_configs, [], fn (config, acc) ->
      [Supervisor.child_spec({MessageSorter.Sorter, config}, id: config.name)] ++ acc
    end)
  end
end
