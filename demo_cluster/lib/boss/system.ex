defmodule Boss.System do
  use DynamicSupervisor
  require Logger

  def start() do
    node_type = Boss.Utils.common_prepare()
    Logger.debug("Start Application")
    start_link()
    DynamicSupervisor.start_child(__MODULE__,%{id: Boss.Operator.Supervisor, start: {Boss.Operator, :start_link,[node_type]}})
    Process.sleep(500)
    start_module(Comms, node_type)
    Process.sleep(200)
    start_module(MessageSorter, node_type)
    Process.sleep(200)
    start_module(Cluster, node_type)
    Process.sleep(500)
    # generic_modules = [Cluster, Logging, Time]
    # start_modules(generic_modules, node_type)
  end

  def start_link() do
    Logger.info("Start Boss Supervisor")
    Common.Utils.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_module(atom(), binary()) :: atom()
  def start_module(module, node_type) do
    Logger.info("Boss Starting Module: #{module}")
    config = Boss.Utils.get_config(module, node_type)
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: Module.concat(module, Supervisor),
        start: {
          Module.concat(module, System),
          :start_link,
          [config]
        }
      }
    )
  end

  @spec start_modules(list(), binary()) :: atom()
  def start_modules(modules, node_type) do
    Enum.each(modules, fn module ->
      start_module(module, node_type)
    end)
  end
end
