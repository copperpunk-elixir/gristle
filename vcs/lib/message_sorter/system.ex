defmodule MessageSorter.System do
  # use DynamicSupervisor
  use Supervisor
  require Logger

  def start_link(vehicle_type) do
    Logger.debug("Start MessageSorter Supervisor")
    Common.Utils.start_link_redudant(Supervisor, __MODULE__, vehicle_type, __MODULE__)
    # Common.Utils.start_link_redudant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
    # case DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__) do
    #   {:ok, pid} ->
    #     Logger.debug("MessageSorter successfully started")
    #     {:ok, pid}
    #   {:error, {:already_started, pid}} ->
    #     Logger.debug("MessageSorter already started at #{inspect(pid)}. This is fine.")
    #     {:ok, pid}
    # end
  end

  @impl true
  def init(vehicle_type) do
    vehicle_module = Module.concat([Configuration.Vehicle, vehicle_type])
    children = get_all_children(vehicle_module)
    Supervisor.init(children, strategy: :one_for_one)
    # DynamicSupervisor.init(strategy: :one_for_one)
  end

  # def child_spec(arg) do
  #   %{
  #     id: arg.name,
  #     start: {__MODULE__, :start_link, [arg]},
  #   }
  # end

  # def start_sorter(config) do
  #   DynamicSupervisor.start_child(
  #     __MODULE__,
  #     %{
  #       id: config.name,
  #       start: {
  #         MessageSorter.Sorter,
  #         :start_link,
  #         [
  #           config
  #         ]}
  #       }
  #    )
  # end

  def get_all_children(vehicle_module) do
    generic_sorters = Configuration.Generic.get_sorter_configs()
    vehicle_sorters = apply(vehicle_module, :get_sorter_configs, [])
    sorter_configs = generic_sorters ++ vehicle_sorters
    Enum.reduce(sorter_configs, [], fn (config, acc) ->
      [Supervisor.child_spec({MessageSorter.Sorter, config}, id: config.name)] ++ acc
    end)
  end
end
