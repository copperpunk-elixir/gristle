defmodule SwarmHeartbeat.Hb do
  use GenServer
  require Logger

  def get_default_config() do
    %{
      registry_module: Comms.ProcessRegistry,
      registry_function: :via_tuple
    }
  end

  def start_link(config) do
    Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_link()
    # process_registry_id = config.process_registry_id
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, config.name)
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(pid, :begin)
    GenServer.cast(pid, :start_heartbeat)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        registry_module: config.registry_module,
        registry_function: config.registry_function,
        node_sorter: nil,
        ward_sorter: nil,
        heartbeat_loop_interval_ms: 5000,
        heartbeat_timer: nil,
        node_ward_status_map: %{},
        swarm_status: 0
     }}
  end

  def handle_cast(:begin, state) do
    Process.sleep(100)
    node_sorter = apply(state.registry_module, state.registry_function, [MessageSorter, {:hb,:node}])
    ward_sorter = apply(state.registry_module, state.registry_function, [MessageSorter, {:hb,:ward}])
    MessageSorter.System.start_sorter(node_sorter)
    MessageSorter.System.start_sorter(ward_sorter)
    {:noreply, %{state | node_sorter: node_sorter, ward_sorter: ward_sorter}}
  end

  def handle_cast({:add_heartbeat, node, ward, time_validity_ms}, state) do
    MessageSorter.Sorter.add_message(state.node_sorter, [node], time_validity_ms, {node, ward})
    MessageSorter.Sorter.add_message(state.ward_sorter, [node], time_validity_ms, node)
    {:noreply, state}
  end

  def handle_cast(:start_heartbeat, state) do
    state =
      case :timer.send_interval(state.heartbeat_loop_interval_ms, self(), :calc_heartbeat_status) do
        {:ok, heartbeat_timer} ->
          %{state | heartbeat_timer: heartbeat_timer}
        {_, reason} ->
          IO.puts("Could not start heartbeat timer: #{inspect(reason)}")
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
          IO.puts("Could not stop heartbeat timer: #{inspect(reason)}")
          state
      end
    {:noreply, state}
  end

  def handle_call(:is_swarm_healthy, _from, state) do
    swarm_healthy = state.swarm_status == 1
    {:reply, swarm_healthy , state}
  end

  def handle_call({:is_node_healthy, node}, _from, state) do
    node_healthy = get_node_status(state.node_ward_status_map, node) == 1
    {:reply, node_healthy, state}
  end

  @impl GenServer
  def handle_info(:calc_heartbeat_status, state) do
    # Get Heartbeat status
    node_ward_list = get_node_ward_list(state.node_sorter)
    IO.puts("Node_ward_list: #{inspect(node_ward_list)}")
    ward_status_list = get_ward_status_list(state.ward_sorter)
    IO.puts("ward_status_list: #{inspect(ward_status_list)}")

    node_ward_status_map = get_node_ward_status_map(node_ward_list, ward_status_list)
    IO.puts("node_ward_status: #{inspect(node_ward_status_map)}")
    swarm_status = get_swarm_status(node_ward_status_map)
    IO.puts("swarm status: #{swarm_status}")
    {:noreply, %{state | node_ward_status_map: node_ward_status_map, swarm_status: swarm_status}}
  end

  def get_node_ward_list(node_sorter) do
    node_messages = MessageSorter.Sorter.get_all_messages(node_sorter)
    Enum.reduce(node_messages, [], fn node_msg, acc ->
      [node_msg.value | acc]
    end)
  end

  def get_ward_status_list(ward_sorter) do
    ward_messages = MessageSorter.Sorter.get_all_messages(ward_sorter)
    Enum.reduce(ward_messages, [], fn ward_msg, acc ->
      [ward_msg.value | acc]
    end)
  end

  def get_node_ward_status_map(node_ward_list, ward_status_list) do
    Enum.reduce(node_ward_list, %{}, fn {node, ward}, acc ->
      if Enum.member?(ward_status_list, ward) do
        Map.put(acc, node, 1)
      else
        Map.put(acc, node, 0)
      end
    end)
  end

  def get_swarm_status(node_ward_status_map) do
    # Create list of unhealthy nodes. A healthy swarm will have an empty list
    case Enum.empty?(node_ward_status_map) do
      true -> 0
      false ->
        node_unhealthy_list =
          Enum.reduce(node_ward_status_map,[], fn {node, status}, acc ->
            if status == 0 do
              [node | acc]
            else
              acc
            end
          end)
        if Enum.empty?(node_unhealthy_list) do
          1
        else
          0
        end
    end
  end

  def get_node_status(node_ward_status_map, node) do
    Map.get(node_ward_status_map, node)
  end

  def add_heartbeat(process, node, ward, time_validity_ms) do
    GenServer.cast(process, {:add_heartbeat, node, ward, time_validity_ms})
  end

  def swarm_healty?(process) do
    GenServer.call(process, :is_swarm_healthy)
  end

  def node_healthy?(process, node) do
    GenServer.call(process, {:is_node_healthy, node})
  end
end
