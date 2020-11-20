defmodule Cluster.Heartbeat do
  use GenServer
  require Logger

  @node_sorter {:hb, :node}

  def start_link(config) do
    Logger.info("Start Cluster.Heartbeat GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config} , _state) do
    {_heartbeat_classification, heartbeat_time_validity_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, {:hb, :node})
    state = %{
      node: Keyword.fetch!(config, :node),
      hb_map: %{node: Keyword.fetch!(config, :node), ward: Keyword.fetch!(config, :ward)},
      heartbeat_time_validity_ms: heartbeat_time_validity_ms,
      cluster_status: -1,
      all_nodes: %{},
      store_cluster_status: Keyword.fetch!(config, :node) > -1
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :add_heartbeat, self())
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :heartbeat_loop_interval_ms), :heartbeat_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:add_heartbeat, heartbeat_map, time_validity_ms}, state) do
    # Logger.debug("add heartbeat: #{inspect(heartbeat_map)}")
    MessageSorter.Sorter.add_message(@node_sorter, [heartbeat_map.node], time_validity_ms, heartbeat_map)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:remove_all_heartbeats, state) do
    MessageSorter.Sorter.remove_all_messages(@node_sorter)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(msg, state) do
    Logger.debug("msg: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:is_cluster_healthy, _from, state) do
    cluster_healthy = (state.cluster_status == 1)
    {:reply, cluster_healthy , state}
  end

  @impl GenServer
  def handle_call({:is_node_healthy, node_name}, _from, state) do
    node_healthy = get_node_status(state.all_nodes, node_name) == 1
    {:reply, node_healthy, state}
  end

  @impl GenServer
  def handle_info(:heartbeat_loop, state) do
    # MessageSorter.Sorter.add_message(@node_sorter, [state.node], state.heartbeat_time_validity_ms, state.hb_map)
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,state.hb_map, state.heartbeat_time_validity_ms}, self())
    # Get Heartbeat status
    all_nodes = unpack_heartbeats(state.hb_map)
    |> update_ward_status()
    # all_nodes = update_ward_status(all_nodes)
    cluster_status = get_cluster_status(all_nodes)
    if state.store_cluster_status do
      Peripherals.Uart.Telemetry.Operator.store_data(%{cluster_status: cluster_status})
    end
    Logger.debug("#{inspect(state.hb_map)} status: #{cluster_status}")
    {:noreply, %{state | all_nodes: all_nodes, cluster_status: cluster_status}}
  end

  @spec unpack_heartbeats(map()) :: map()
  def unpack_heartbeats(self_hb) do
    node_messages = MessageSorter.Sorter.get_all_messages(@node_sorter, 100)
    |> Kernel.++([%{value: self_hb}])
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

  def get_cluster_status(all_nodes) do
    # Create list of unhealthy nodes. A healthy cluster will have an empty list
    if Enum.empty?(all_nodes) do
      0
    else
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

  def cluster_healthy?() do
    GenServer.call(__MODULE__, :is_cluster_healthy)
  end

  def node_healthy?(node) do
    GenServer.call(__MODULE__, {:is_node_healthy, node})
  end

  def remove_all_heartbeats(process) do
    GenServer.cast(process, :remove_all_heartbeats)
  end
end
