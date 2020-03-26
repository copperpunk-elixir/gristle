defmodule Actuator.Actuator do
  alias Actuator.Actuator, as: Actuator
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Actuator #{config[:name]}")
    # process_via_tuple = apply(config[:registry_module], config[:registry_function], [__MODULE__, config[:name]])
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: config[:process_via_tuple])
    GenServer.cast(process_id, :start_pids)
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        registry_module: Keyword.get(config, :registry_module),
        registry_function: Keyword.get(config, :registry_function),
        name: Keyword.get(config, :name),
        pids: Keyword.get(config, :pids),
        weight: Keyword.get(config, :weight)
     }}
  end
end
