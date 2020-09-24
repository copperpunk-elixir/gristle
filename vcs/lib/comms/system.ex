defmodule Comms.System do
  use DynamicSupervisor
  require Logger

  def start_link() do
    Logger.info("Start Comms DynamicSupervisor")
    {:ok, pid} = Common.Utils.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
    start_registry()
    {:ok, pid}
  end

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_registry() :: atom()
  def start_registry() do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: :registry,
        start: {
          Comms.ProcessRegistry,
          :start_link,
          []}
      }
    )
  end

  @spec start_operator(atom()) :: atom()
  def start_operator(name) do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: name,
        start: {
          Comms.Operator,
          :start_link,
          [
            %{
              name: name,
              refresh_groups_loop_interval_ms: 100
            }
          ]}
      }
    )
  end
end
