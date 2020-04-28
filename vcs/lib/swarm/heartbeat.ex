defmodule Swarm.Heartbeat do
  use GenServer
  require Logger

  @default_heartbeat_status_loop_interval_ms 100
  @default_send_heartbeat_loop_interval_ms 100
  @default_heartbeat_duration_ms 500
  @node_sorter {:hb, :node}

  def start_link(config \\ %{}) do
    Logger.debug("Start HB")
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config)
    begin()
    start_heartbeat_loops()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    node = Map.get(config, :node, 0)
    ward = Map.get(config, :ward, 0)
    {:ok, %{
        node: node,
        hb_map: %{node: node, ward: ward},
        heartbeat_status_loop_interval_ms: Map.get(config, :heartbeat_status_loop_interval_ms, @default_heartbeat_status_loop_interval_ms),
        heartbeat_status_loop_timer: nil,
        send_heartbeat_loop_interval_ms: Map.get(config, :send_heartbeat_loop_interval_ms, @default_send_heartbeat_loop_interval_ms),
        send_heartbeat_loop_timer: nil,
        swarm_status: 0,
        all_nodes: %{}
     }}
  end

  def handle_cast(:begin , state) do
    Process.sleep(100)
    sorter_config = %{
      name: @node_sorter,
    }
    Comms.Operator.start_link(%{name: __MODULE__})
    Comms.Operator.join_group(__MODULE__, @node_sorter, self())
    MessageSorter.System.start_sorter(sorter_config)
    {:noreply, state}
  end


  def handle_cast({:add_heartbeat, heartbeat_map, time_validity_ms}, state) do
    MessageSorter.Sorter.add_message(@node_sorter, [heartbeat_map.node], time_validity_ms, heartbeat_map)
    {:noreply, state}
  end

  def handle_cast(:remove_all_heartbeats, state) do
    MessageSorter.Sorter.remove_all_messages(@node_sorter)
    {:noreply, state}
  end

  def handle_cast(:start_heartbeat_loops, state) do
    heartbeat_status_loop_timer = Common.Utils.start_loop(self(), state.heartbeat_status_loop_interval_ms, :calc_heartbeat_status)
    send_heartbeat_loop_timer = Common.Utils.start_loop(self(), state.send_heartbeat_loop_interval_ms, :send_heartbeat)
    {:noreply, %{state | heartbeat_status_loop_timer: heartbeat_status_loop_timer, send_heartbeat_loop_timer: send_heartbeat_loop_timer}}
  end

  @impl GenServer
  def handle_cast(:stop_heartbeat_loops, state) do
    heartbeat_status_loop_timer = Common.Utils.stop_loop(state.heartbeat_status_loop_timer)
    send_heartbeat_loop_timer = Common.Utils.stop_loop(state.send_heartbeat_loop_timer)
    {:noreply, %{state | heartbeat_status_loop_timer: heartbeat_status_loop_timer, send_heartbeat_loop_timer: send_heartbeat_loop_timer}}
  end

  def handle_cast(msg, state) do
    Logger.warn("msg: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:is_swarm_healthy, _from, state) do
    swarm_healthy = state.swarm_status == 1
    {:reply, swarm_healthy , state}
  end

  @impl GenServer
  def handle_call({:is_node_healthy, node_name}, _from, state) do
    node_healthy = get_node_status(state.all_nodes, node_name) == 1
    {:reply, node_healthy, state}
  end

  @impl GenServer
  def handle_info(:calc_heartbeat_status, state) do
    # Get Heartbeat status
    all_nodes = unpack_heartbeats()
    Logger.debug("All node heartbeats: #{inspect(all_nodes)}")
    all_nodes = update_ward_status(all_nodes)
    swarm_status = get_swarm_status(all_nodes)
    Logger.debug("swarm status: #{swarm_status}")
    {:noreply, %{state | all_nodes: all_nodes, swarm_status: swarm_status}}
  end

  @impl GenServer
  def handle_info(:send_heartbeat, state) do
    MessageSorter.Sorter.add_message(@node_sorter, [state.node], @default_heartbeat_duration_ms, state.hb_map)
    {:noreply, state}
  end

  def unpack_heartbeats() do
    node_messages = MessageSorter.Sorter.get_all_messages(@node_sorter)
    Enum.reduce(node_messages, %{}, fn (node_msg, acc) ->
      hb = node_msg.value
      node = %{ward: hb.ward}
      Map.put(acc, hb.node, node)
    end)
  end

  def update_ward_status(nodes) do
    Enum.reduce(nodes, nodes, fn {node_name, node}, acc ->
      if Map.has_key?(nodes, node.ward) do
        node = Map.put(node, :status, 1)
        Map.put(acc, node_name, node)
      else
        node = Map.put(node, :status, 0)
        Map.put(acc, node_name, node)
      end
    end)
  end

  def get_swarm_status(all_nodes) do
    # Create list of unhealthy nodes. A healthy swarm will have an empty list
    case Enum.empty?(all_nodes) do
      true -> 0
      false ->
        node_unhealthy_list =
          Enum.reduce(all_nodes,[], fn {_node_name, node}, acc ->
            if node.status == 0 do
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

  def get_node_status(all_nodes, node_name) do
    get_in(all_nodes, [node_name, :status])
  end

  def add_heartbeat(heartbeat_map) do
    # GenServer.cast(__MODULE__, {:add_heartbeat, heartbeat_map, time_validity_ms})
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat, heartbeat_map, @default_heartbeat_duration_ms}, {:hb, :node}, nil)
  end

  def swarm_healthy?() do
    GenServer.call(__MODULE__, :is_swarm_healthy)
  end

  def node_healthy?(node) do
    GenServer.call(__MODULE__, {:is_node_healthy, node})
  end

  def remove_all_heartbeats(process) do
    GenServer.cast(process, :remove_all_heartbeats)
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp start_heartbeat_loops() do
    GenServer.cast(__MODULE__, :start_heartbeat_loops)
  end
end
