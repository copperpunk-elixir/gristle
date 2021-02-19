defmodule Cluster.Network do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Cluster.Network")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Logger.debug("cluster.network begin")
    state = %{
      node_name_with_domain: nil,
      ip_address: nil,
      socket: nil,
      src_port: Keyword.fetch!(config, :src_port),
      dest_port: Keyword.fetch!(config, :dest_port),
      cookie: Keyword.fetch!(config, :cookie),
      broadcast_ip_loop_interval_ms: Keyword.fetch!(config, :broadcast_ip_loop_interval_ms),
      broadcast_ip_loop_timer: nil,
      interface: Keyword.fetch!(config, :interface),
      connected_to_network: false
    }
    Comms.System.start_operator(__MODULE__)
    if Common.Utils.is_target?() and !is_nil(state.interface) do
      Logger.debug("Connect to network interface: #{inspect(state.interface)}")
      VintageNet.configure(state.interface, Keyword.fetch!(config, :vintage_net_config))
      GenServer.cast(__MODULE__, :connect_to_network)
    else
      Logger.debug("Network connection not required.")
      Logger.debug("Tell Boss to start remaining processes")
      Boss.Operator.start_node_processes()
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:connect_to_network, state) do
    connected = (VintageNet.get(["interface", state.interface, "lower_up"]) == true)
    if connected do
      Logger.debug("Network connected.")
      GenServer.cast(__MODULE__, :start_node_and_broadcast)
    else
      Logger.debug("No network connection. Retrying in 1 second.")
      Process.sleep(1000)
      GenServer.cast(__MODULE__, :connect_to_network)
    end
    {:noreply, %{state | connected_to_network: connected}}
  end

  @impl GenServer
  def handle_cast(:start_node_and_broadcast, state) do
    ip_address_temp = get_ip_address(state.interface)
    Logger.debug("IPaddress: #{inspect(ip_address_temp)}")
    state =
      case ip_address_temp do
        nil ->
          Logger.debug("#{state.interface} is not connected. Try again in 1 second")
          Process.sleep(1000)
          GenServer.cast(self(), :start_node_and_broadcast)
          state
        ip_address->
          unique_node_name_with_domain = Cluster.Network.NodeConnection.get_unique_node_name_with_domain(ip_address)
          Logger.debug("#{unique_node_name_with_domain}")
          Cluster.Network.NodeConnection.start_node(unique_node_name_with_domain, state.cookie)
          {socket, src_port} =  open_socket(state.src_port, 0)
          Logger.debug("start broadcast_ip loop")
          broadcast_ip_loop_timer = Common.Utils.start_loop(self(), state.broadcast_ip_loop_interval_ms, :broadcast_ip_loop)
          Logger.debug("Tell Boss to start remaining processes")
          Boss.Operator.start_node_processes()
          %{state |
            ip_address: ip_address,
            node_name_with_domain: unique_node_name_with_domain,
            socket: socket,
            src_port: src_port,
            broadcast_ip_loop_timer: broadcast_ip_loop_timer
          }
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:broadcast_ip_loop, state) do
    # Logger.debug("node list: #{inspect(Node.list)}")
    if Enum.empty?(Node.list) do
      Cluster.Network.NodeConnection.broadcast_node(state.socket, state.ip_address, state.node_name_with_domain, state.dest_port)
    else
      Logger.debug("Node network has been discovered and is connected.")
      # Stop the timer
      case :timer.cancel(state.broadcast_ip_loop_timer) do
        {:ok, _} -> Logger.debug("Broadcast timer stopped")
        {_, reason} -> Logger.debug("Could not stop broadcast timer: #{inspect(reason)}")
      end
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:udp, socket, src_ip, src_port, msg}, state) do
    Cluster.Network.NodeConnection.process_udp_message(socket, src_ip, src_port, msg, state.ip_address, state.src_port)
    {:noreply, state}
  end

  @spec get_ip_address(binary()) :: tuple()
  def get_ip_address(interface) do
    all_ip_configs = VintageNet.get(["interface", interface, "addresses"])
    # Logger.debug("all ip configs: #{inspect(all_ip_configs)}")
    if is_nil(all_ip_configs) do
      nil
    else
      get_inet_ip_address(all_ip_configs)
    end
  end

  @spec get_inet_ip_address(list()) :: tuple()
  def get_inet_ip_address(all_ip_configs) do
    {[config], remaining} = Enum.split(all_ip_configs, 1)
    cond do
      config.family == :inet ->
        Logger.debug("Found #{inspect(config.address)} for family: #{config.family}")
        config.address
      Enum.empty?(remaining) -> nil
      true -> get_inet_ip_address(remaining)
    end
  end

  @spec open_socket(integer(), integer()) :: {any(), integer()}
  def open_socket(src_port, attempts) do
    Logger.debug("open socket on port #{src_port}")
    if (attempts > 10) do
      raise "Could not open socket after 10 attempts"
    end
    case :gen_udp.open(src_port, [broadcast: true, active: true]) do
      {:ok, socket} -> {socket, src_port}
      {:error, :eaddrinuse} -> open_socket(src_port+1, attempts+1)
      other -> raise "Unknown error: #{inspect(other)}"
    end
  end
end
