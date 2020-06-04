defmodule Cluster.Network do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Cluster Network")
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        node_name_with_domain: nil,
        ip_address: nil,
        socket: nil,
        port: config.port,
        cookie: config.cookie,
        broadcast_ip_loop_interval_ms: config.broadcast_ip_loop_interval_ms,
        broadcast_ip_loop_timer: nil,
        interface: config.interface,
        is_embedded: config.is_embedded
     }}
  end

  @impl GenServer
  def handle_cast(:begin , state) do
    Process.sleep(100)
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    if (state.is_embedded) do
      # We must first connect to the network
      GenServer.cast(__MODULE__, :connect_to_network)
    else
      GenServer.cast(__MODULE__, :start_node_and_broadcast)
    end
    {:noreply, state}
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
          # node_name_with_domain = Cluster.Network.NodeConnection.get_node_name_with_domain(state.node_name, ip_address)
          unique_node_name_with_domain = Cluster.Network.NodeConnection.get_unique_node_name_with_domain(ip_address)
          Logger.warn("#{unique_node_name_with_domain}")
          # Cluster.Network.NodeConnection.start_node(node_name_with_domain, state.cookie)
          Cluster.Network.NodeConnection.start_node(unique_node_name_with_domain, state.cookie)
          # :random.seed(:erlang.phash2([node()]),
            # :erlang.monotonic_time(),
            # :erlang.unique_integer())
          # port = :random.uniform(10000)
          socket = Cluster.Network.NodeConnection.open_socket_active(state.port)
          GenServer.cast(__MODULE__, :start_broadcast_ip_loop)
          %{state | ip_address: ip_address, node_name_with_domain: unique_node_name_with_domain, socket: socket}
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
    Logger.info("node list: #{inspect(Node.list)}")
    broadcast_ip_loop_timer =
    if Node.list == [] do
      Cluster.Network.NodeConnection.broadcast_node(state.socket, state.ip_address, state.node_name_with_domain, state.port)
      state.broadcast_ip_loop_timer
    else
      # Stop the timer
      # case :timer.cancel(state.broadcast_ip_loop_timer) do
      #   {:ok, } ->
      #     Logger.debug("Broadcast timer stopped")
      #     nil
      #   {_, reason} ->
      #     Logger.debug("Could not stop broadcast timer: #{inspect(reason)}")
      #     state.broadcast_ip_loop_timer
      # end

    end
    {:noreply, %{state | broadcast_ip_loop_timer: broadcast_ip_loop_timer}}
  end

  @impl GenServer
  def handle_info({:udp, socket, source_ip, port, msg}, state) do
    Cluster.Network.NodeConnection.process_udp_message(socket, source_ip, port, msg, state.ip_address, state.port)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_ip_address, _from, state) do
    ip_address = get_ip_address(state.interface)
    {:reply, ip_address, state}
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



  @spec configure_wifi() :: atom()
  def configure_wifi() do
    interface = "wlp0s20f3"
     config = %{
       type: VintageNetWiFi,
       vintage_net_wifi: %{
         networks: [
           %{
             key_mgmt: :wpa_psk,
             ssid: "dialup",
             psk: "binghamplace",
           }
         ]
       },
       ipv4: %{method: :dhcp},
     }
    VintageNet.configure(interface, config)
  end
end
