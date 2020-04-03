defmodule Control.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Control.Controller")
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(__MODULE__, :start_control_loop)
    GenServer.cast(__MODULE__, :start_message_sorter_system)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        pv_cmds: %{},
        pv_values: %{},
        control_loop_timer: nil,
        control_loop_interval_ms: Map.get(config, :control_loop_interval_ms, 0)
     }}
  end

  @impl GenServer
  def handle_cast(:start_message_sorter_system, state) do
    {:ok, pid} = MessageSorter.System.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_control_loop, state) do
    control_loop_timer = Common.Utils.start_loop(self(), state.control_loop_interval_ms, :control_loop)
    state = %{state | control_loop_timer: control_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_control_loop, state) do
    control_loop_timer = Common.Utils.stop_loop(state.control_loop_timer)
    state = %{state | control_loop_timer: control_loop_timer}
    {:noreply, state}
  end

  def start_message_sorter_system() do
    GenServer.cast(__MODULE__, :start_message_sorter_system)
  end

  def start_message_sorter(pv) do
    MessageSorter.System.start_sorter({:controller_cmds, pv})
  end

end
