defmodule Actuation.Actuator do
  alias Actuation.Actuator, as: Actuator
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Actuator #{config[:name]}")
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: via_tuple(config[:name]))
    GenServer.cast(process_id, :start_pids)
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        name: Keyword.get(config, :name),
        pids: Keyword.get(config, :pids),
        weight: Keyword.get(config, :weight)
     }}
  end

  def via_tuple(actuator) do
    Comms.ProcessRegistry.via_tuple(__MODULE__, actuator)
  end
end
