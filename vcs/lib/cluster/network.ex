defmodule Cluster.Network do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Cluster.Network GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        connection_required: config.connection_required,
        node_name_with_domain: nil,
        ip_address: nil,
        socket: nil,
        src_port: config.src_port,
        dest_port: config.dest_port,
        cookie: config.cookie,
        broadcast_ip_loop_interval_ms: config.broadcast_ip_loop_interval_ms,
        broadcast_ip_loop_timer: nil,
        interface: config.interface,
        vintage_net_access: config.vintage_net_access,
        vintage_net_config: config.vintage_net_config,
        connected_to_network: false
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin , state) do
    Process.sleep(100)
    Comms.System.start_operator(__MODULE__)
    if (state.vintage_net_access) do
      VintageNet.configure(state.interface, state.vintage_net_config)
    end
    if state.connection_required do
      GenServer.cast(__MODULE__, :connect_to_network)
    else
      Logger.debug("Network connection not required.")
      Common.Application.start_remaining_processes()
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:connect_to_network, state) do
    connected = VintageNet.get(["interface", state.interface, "lower_up"])
    connected =  if (connected), do: true, else: false
    if connected == true do
      Logger.debug("Network connected.")
      GenServer.cast(__MODULE__, :start_node_and_broadcast)
      # Common.Application.start_remaining_processes()
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
          GenServer.cast(__MODULE__, :start_broadcast_ip_loop)
          %{state | ip_address: ip_address, node_name_with_domain: unique_node_name_with_domain, socket: socket, src_port: src_port}
      end
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast(:start_broadcast_ip_loop, state) do
    Logger.debug("start broadcast_ip loop")
    broadcast_ip_loop_timer = Common.Utils.start_loop(self(), state.broadcast_ip_loop_interval_ms, :broadcast_ip_loop)
    {:noreply, %{state | broadcast_ip_loop_timer: broadcast_ip_loop_timer}}
  end

  @impl GenServer
  def handle_info(:broadcast_ip_loop, state) do
    # Logger.debug("node list: #{inspect(Node.list)}")
    broadcast_ip_loop_timer =
    if Node.list == [] and state.socket != nil do
      Cluster.Network.NodeConnection.broadcast_node(state.socket, state.ip_address, state.node_name_with_domain, state.dest_port)
      state.broadcast_ip_loop_timer
    else
      # Stop the timer
      case :timer.cancel(state.broadcast_ip_loop_timer) do
        {:ok, _} ->
          Logger.debug("Broadcast timer stopped")
          nil
        {_, reason} ->
          Logger.debug("Could not stop broadcast timer: #{inspect(reason)}")
          state.broadcast_ip_loop_timer
      end
    end
    {:noreply, %{state | broadcast_ip_loop_timer: broadcast_ip_loop_timer}}
  end

  @impl GenServer
  def handle_info({:udp, socket, src_ip, src_port, msg}, state) do
    Cluster.Network.NodeConnection.process_udp_message(socket, src_ip, src_port, msg, state.ip_address, state.src_port)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_ip_address, _from, state) do
    ip_address = get_ip_address(state.interface)
    {:reply, ip_address, state}
  end

  @impl GenServer
  def handle_call(:is_connected, _from, state) do
    {:reply, state.connected_to_network, state}
  end

  @spec get_ip_address() :: tuple()
  def get_ip_address() do
    GenServer.call(__MODULE__, :get_ip_address)
  end

  @spec get_ip_address(binary()) :: tuple()
  defp get_ip_address(interface) do
    ip_addresses = VintageNet.get(["interface", interface, "addresses"])
    Logger.debug("ip addreses: #{inspect(ip_addresses)}")
    case ip_addresses do
      nil ->
        Logger.debug("#{interface} is not connected yet")
        nil
      addresses ->
        Enum.reduce(addresses, nil, fn (address, acc) ->
          if address.family == :inet do
            Logger.debug("Found #{inspect(address.address)} for family: #{address.family}")
            address.address
          else
            acc
          end
        end)
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

  @spec connected_to_network?() :: boolean()
  def connected_to_network?() do
    GenServer.call(__MODULE__, :is_connected)
  end
end
