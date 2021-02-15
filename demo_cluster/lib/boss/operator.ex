defmodule Boss.Operator do
  use GenServer
  require Logger

  def start_link(node_type) do
    Logger.debug("Start Boss.Operator")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, node_type})
    {:ok, pid}

  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, node_type}, _state) do
    state = %{
      node_type: node_type
    }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_node_processes, state) do
    Logger.info("Boss Operator start_node_processes")
    node_type = state.node_type
    Logger.debug("Start remaining processes for #{node_type}")
    modules = Boss.Utils.get_remaining_modules()
    Boss.System.start_modules(modules, node_type)
    {:noreply, state}
  end

  @spec start_node_processes() :: atom()
  def start_node_processes do
    GenServer.cast(__MODULE__, :start_node_processes)
  end
end
