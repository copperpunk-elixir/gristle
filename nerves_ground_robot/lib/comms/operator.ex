defmodule Comms.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start CommsOperator")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    Logger.debug("call start_node")
    GenServer.cast(pid, :start_node_and_broadcast)
    # Logger.debug("Connect nodes")
    # GenServer.call(pid, :connect_nodes)
    # Logger.debug("cast register_global")
    # GenServer.cast(pid, :register_pg2)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        node_name: config.node_name,
        node_name_with_domain: nil,
        ip_address_tuple: nil,
        socket: nil,
        # nodes_to_connect: config.nodes_to_connect,
        groups: config.groups,
        interface: config.interface,
        cookie: config.cookie,
        broadcast_timer: nil,
        broadcast_timer_interval_ms: 5000
     }}
  end

  @impl GenServer
  def handle_cast(:start_node_and_broadcast, state) do
    ip_address_tuple_temp = Comms.NodeConnection.get_ip_address_tuple(state.interface)
    Logger.debug("IPaddresstuple: #{inspect(ip_address_tuple_temp)}")
    state =
      case ip_address_tuple_temp do
        nil ->
          Logger.debug("#{state.interface} is not connected. Try again in 5 seconds")
          Process.sleep(5000)
          GenServer.cast(self(), :start_node_and_broadcast)
          state
        ip_address_tuple ->
          node_name_with_domain = Comms.NodeConnection.get_node_name_with_domain(state.node_name, ip_address_tuple)
          Comms.NodeConnection.start_node(node_name_with_domain, state.cookie)
          socket = Comms.NodeConnection.open_socket()
          broadcast_timer = start_broadcast_timer(state.broadcast_timer_interval_ms)
          create_and_join_global_groups(state.groups)
          %{state | ip_address_tuple: ip_address_tuple, node_name_with_domain: node_name_with_domain, socket: socket, broadcast_timer: broadcast_timer}
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:publish, group, message}, state) do
    # Logger.debug("publish to group #{group}: #{inspect(message)}")
    Common.Utils.global_dispatch_cast(group, message, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:global,{registry, topic, message}}, state) do
    Common.Utils.dispatch_cast(
      registry,
      topic,
      message
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:broadcast_node_info, state) do
    broadcast_timer =
    if Node.list == [] do
      Comms.NodeConnection.broadcast_node(state.socket, state.ip_address_tuple, state.node_name_with_domain)
      state.broadcast_timer
    else
      stop_broadcast_timer(state.broadcast_timer)
    end
    {:noreply, %{state | broadcast_timer: broadcast_timer}}
  end

  @impl GenServer
  def handle_info({:udp, socket, source_ip, port, msg}, state) do
    Comms.NodeConnection.process_udp_message(socket, source_ip, port, msg, state.ip_address_tuple)
    {:noreply, state}
  end

  defp start_broadcast_timer(timer_interval_ms) do
    case :timer.send_interval(timer_interval_ms, self(), :broadcast_node_info) do
      {:ok, broadcast_timer} ->
        Logger.debug("Broadcast timer started with #{timer_interval_ms}ms interval")
        broadcast_timer
      {_, reason} ->
        Logger.debug("Could not start broadcast timer: #{inspect(reason)}")
        nil
    end
  end

  defp stop_broadcast_timer(broadcast_timer) do
    case :timer.cancel(broadcast_timer) do
      {:ok, } ->
        Logger.debug("Broadcast timer stopped")
        nil
      {_, reason} ->
        Logger.debug("Could not stop joystick timer: #{inspect(reason)}")
        broadcast_timer
    end
  end

  defp create_and_join_global_groups(groups) do
    IO.puts("register process")
    # :syn.register(node_name, self())
    Enum.each(groups, fn group ->
      Logger.debug("Create pg2 group: #{group}")
      Logger.debug(:pg2.create(group))
      Logger.debug("#{inspect(self())} joining group #{group}")
      :pg2.join(group, self())
    end)
  end

  def publish(group, message) do
    GenServer.cast(__MODULE__, {:publish, group, message})
  end

  # def configure_network(interface, ssid \\ nil, psk \\ nil) do
  #   network_config = Common.NodeConfiguration.get_network_config(interface)
  #   case interface do
  #     :wlan0 ->
  #       Logger.debug("Configure wlan0 interface")
  #       # VintageNet.configure("wlan0",network_config)
  #       wait_for_network_connection("wlan0")
  #   end
  # end

  # def wait_for_network_connection(interface, timeout_count \\ 0) do
  #   # network_status = VintageNet.info
  # end
end
