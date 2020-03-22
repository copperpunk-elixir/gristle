defmodule MessageSorter.System do
  use DynamicSupervisor
  require Logger

  def start_link() do
    Logger.debug("Start MessageSorter Supervisor")
    case DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__) do
      {:ok, pid} ->
        Logger.debug("MessageSorter successfully started")
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("MessageSorter already started at #{inspect(pid)}. This is fine.")
        {:ok, pid}
    end
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

  def start_sorter(process_via_tuple) do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: process_via_tuple,
        start: {
          MessageSorter.Sorter,
          :start_link,
          [
            process_via_tuple
          ]}
        }
     )
  end
end
