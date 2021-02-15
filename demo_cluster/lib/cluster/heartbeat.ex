defmodule Cluster.Heartbeat do
  use GenServer
  require Logger

  @node_sorter {:hb, :node}

  def start_link(config) do
    Logger.debug("Start Cluster.Heartbeat")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config} , _state) do
    {_heartbeat_classification, heartbeat_time_validity_ms} = Configuration.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, {:hb, :node})
    num_nodes = Keyword.fetch!(config, :num_nodes)
    state = %{
      num_nodes: num_nodes,
      all_expected_nodes: Enum.to_list(0..num_nodes-1),
      node_and_ward: {Keyword.fetch!(config, :node), Keyword.fetch!(config, :ward)},
      heartbeat_time_validity_ms: heartbeat_time_validity_ms,
      cluster_status: -1,
      all_nodes_wards: %{},
      store_cluster_status: Keyword.fetch!(config, :node) > -1
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :node_heartbeat, self())
    Registry.register(MessageSorterRegistry, {@node_sorter, :messages}, Keyword.fetch!(config, :heartbeat_node_sorter_interval_ms))
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :heartbeat_loop_interval_ms), :heartbeat_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:node_heartbeat, {node, ward}, time_validity_ms}, state) do
    # Logger.debug("node heartbeat: #{node}/#{ward}/#{time_validity_ms}")
    MessageSorter.Sorter.add_message(@node_sorter, [node, ward], time_validity_ms, {node, ward})
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:message_sorter_messages, @node_sorter, all_node_messages}, state) do
    # Logger.debug("message sorter message: #{inspect(all_node_messages)}")
    # Nodes and Wards stored as key/value pair, i.e., %{node => ward}
    all_nodes_wards =
      Enum.reduce(all_node_messages, %{}, fn (message, acc) ->
        {node, ward} = message.value
        Map.put(acc, node, ward)
      end)
    {:noreply, %{state | all_nodes_wards: all_nodes_wards}}
  end

  @impl GenServer
  def handle_info(:heartbeat_loop, state) do
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:node_heartbeat, state.node_and_ward, state.heartbeat_time_validity_ms}, nil)
    # Get Heartbeat status
    num_nodes = state.num_nodes
    all_expected_nodes = state.all_expected_nodes
    # Logger.info("all nodes #{inspect(state.all_nodes_wards)}")
    healthy_nodes = Map.take(state.all_nodes_wards, all_expected_nodes) |> Map.keys()
    cluster_status = if length(healthy_nodes) == num_nodes, do: 1, else: 0

    if cluster_status < 1 do
      unhealthy_nodes = all_expected_nodes -- healthy_nodes
      Logger.warn("unhealthy nodes: #{inspect(unhealthy_nodes)}")
    end

    if state.store_cluster_status do
      # Blink LEDS
    end
    # Logger.debug("#{inspect(state.node_and_ward)} status: #{cluster_status}")
    {:noreply, %{state | cluster_status: cluster_status}}
  end

end
