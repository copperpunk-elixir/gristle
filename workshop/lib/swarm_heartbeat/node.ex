defmodule SwarmHeartbeat.Node do
  use GenServer
  require Logger

  def start_link(config) do
    Comms.ProcessRegistry.start_link()
    # process_registry_id = config.process_registry_id
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, config.name)
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(pid, :begin)
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        registry_module: config.registry_module,
        registry_function: config.registry_function,
        ward: config.ward,
        heartbeat_group: config.heartbeat_group
     }}
  end

  def handle_cast(:begin, state) do
    :pg2.create(state.heartbeat_group)
    :pg2.join(self(), state.heartbeat_group)
    MessageSorter.System.start_sorter({__MODULE__, {:state.name, :ward}}, 0, 2)
    MessageSorter.System.start_sorter({__MODULE__, {:state.name, :guardian}}, 0, 1)
    MessageSorter.System.start_sorter({__MODULE__, {:state.name, :all}}, 0, 1)
  end

  def handle_cast(:start_heartbeat, state) do
    state =
      case :timer.send_interval(state.heartbeat_loop_interval_ms, self(), :send_heartbeat) do
        {:ok, heartbeat_timer} ->
          %{state | heartbeat_timer: heartbeat_timer}
        {_, reason} ->
          Logger.debug("Could not start heartbeat timer: #{inspect(reason)}")
          state
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_heartbeat, state) do
    state =
      case :timer.cancel(state.heartbeat_timer) do
        {:ok, } ->
          %{state | heartbeat_timer: nil}
        {_, reason} ->
          Logger.debug("Could not stop heartbeat timer: #{inspect(reason)}")
          state
      end
    {:noreply, state}
  end

  def handle_info(:send_heartbeat, state) do
    # Get Heartbeat status
    ward_status = if state.ward_alive, do: 2, else: 0
    guardian_status = if state.guardian_alive,  do: 1, else: 0
    node_status = ward_status + guardian_status
    Enum.each(:pg2.get_members(state.heartbeat_group), fn pid ->
      GenServer.cast(pid, {:heartbeat, state.name, node_status})
    end)


  end
end
