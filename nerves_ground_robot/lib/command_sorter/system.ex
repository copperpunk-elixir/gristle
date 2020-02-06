defmodule CommandSorter.System do
  use DynamicSupervisor
  require Logger

  def start_link(_) do
    Logger.debug("Start CommandSorter Supervisor")
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # def child_spec(arg) do
  #   %{
  #     id: arg.name,
  #     start: {__MODULE__, :start_link, [arg]},
  #   }
  # end

  def start_sorter(name, max_priority) do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: name,
        start: {CommandSorter.Sorter, :start_link, [%{name: name, max_priority: max_priority}]}
        }
     )
  end
end
