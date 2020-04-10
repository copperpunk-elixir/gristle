defmodule Swarm.Heartbeat do
  use GenServer
  require Logger

  @default_heartbeat_loop_interval_ms 1000

  def start_link(config) do
    Logger.debug("Start HB process")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    GenServer.cast(pid, :start_heartbeat)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        node_sorter: nil,
        # ward_sorter: nil,
        heartbeat_loop_interval_ms: Map.get(config, :heartbeat_loop_interval_ms, @default_heartbeat_loop_interval_ms),
        heartbeat_timer: nil,
        node_ward_status_map: %{},
        swarm_status: 0,
        all_heartbeats: %{}
     }}
  end

  def handle_cast(:begin , state) do
    Process.sleep(100)
    node_sorter = {:hb,:node}
    # ward_sorter = {:hb,:ward}
    sorter_config = %{
      name: node_sorter,
    }
    {:ok, pid} = Comms.Operator.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    Comms.Operator.join_group(node_sorter, self())
    {:noreply, %{state | node_sorter: node_sorter}}#, ward_sorter: ward_sorter}}
  end


  def handle_cast({:add_heartbeat, heartbeat_map, time_validity_ms}, state) do
    MessageSorter.Sorter.add_message(state.node_sorter, [heartbeat_map.node], time_validity_ms, heartbeat_map)
    # MessageSorter.Sorter.add_message(state.ward_sorter, [node], time_validity_ms, node)
    {:noreply, state}
  end

  def handle_cast(:remove_all_heartbeats, state) do
    MessageSorter.Sorter.remove_all_messages(state.node_sorter)
    # MessageSorter.Sorter.remove_all_messages(state.ward_sorter)
    {:noreply, state}
  end

  def handle_cast(:start_heartbeat, state) do
    heartbeat_timer = Common.Utils.start_loop(self(), state.heartbeat_loop_interval_ms, :calc_heartbeat_status)
    {:noreply, %{state | heartbeat_timer: heartbeat_timer}}
  end

  @impl GenServer
  def handle_cast(:stop_heartbeat, state) do
    heartbeat_timer = Common.Utils.stop_loop(state.heartbeat_timer)
    {:noreply, %{state | heartbeat_timer: heartbeat_timer}}
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
  def handle_call({:is_node_healthy, node}, _from, state) do
    node_healthy = get_node_status(state.node_ward_status_map, node) == 1
    {:reply, node_healthy, state}
  end

  @impl GenServer
  def handle_info(:calc_heartbeat_status, state) do
    # Get Heartbeat status
    all_heartbeats = unpack_heartbeats(state.node_sorter)
    Logger.debug("Node_ward_list: #{inspect(all_heartbeats.node_ward_list)}")
    Logger.debug("node_list: #{inspect(all_heartbeats.node_list)}")

    node_ward_status_map = get_node_ward_status_map(all_heartbeats.node_ward_list, all_heartbeats.node_list)
    Logger.debug("node_ward_status: #{inspect(node_ward_status_map)}")
    swarm_status = get_swarm_status(node_ward_status_map)
    Logger.debug("swarm status: #{swarm_status}")
    {:noreply, %{state | node_ward_status_map: node_ward_status_map, swarm_status: swarm_status, all_heartbeats: all_heartbeats}}
  end

  def unpack_heartbeats(node_sorter) do
    node_messages = MessageSorter.Sorter.get_all_messages(node_sorter)
    hb_map = %{node_ward_list: [], node_list: []}
    Enum.reduce(node_messages, hb_map, fn (node_msg, acc) ->
      hb = node_msg.value
      node_ward_list = [{hb.node, hb.ward} | acc.node_ward_list]
      node_list = [hb.node | acc.node_list]
      %{acc | node_ward_list: node_ward_list, node_list: node_list}
    end)
  end

  def get_node_ward_status_map(node_ward_list, node_status_list) do
    Enum.reduce(node_ward_list, %{}, fn {node, ward}, acc ->
      if Enum.member?(node_status_list, ward) do
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

  def add_heartbeat(heartbeat_map, time_validity_ms) do
    # GenServer.cast(__MODULE__, {:add_heartbeat, heartbeat_map, time_validity_ms})
    Comms.Operator.send_msg_to_group({:add_heartbeat, heartbeat_map, time_validity_ms}, {:hb, :node}, nil)
  end

  def swarm_healthy?() do
    GenServer.call(__MODULE__, :is_swarm_healthy)
  end

  def node_healthy?(node) do
    GenServer.call(__MODULE__, {:is_node_healthy, node})
  end

  # TODO: This should live in TestLand but I don't know how yet
  def test_setup() do
    {:ok, comms_pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(comms_pid)
    {:ok, msg_pid} = MessageSorter.System.start_link()
    Common.Utils.wait_for_genserver_start(msg_pid)
    config = %{
      heartbeat_loop_interval_ms: 100
    }
    {:ok, pid} = start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    Process.sleep(10)
    # remove_all_heartbeats(pid)
    Process.sleep(100)
    pid
  end

  def remove_all_heartbeats(process) do
    GenServer.cast(process, :remove_all_heartbeats)
  end

end
