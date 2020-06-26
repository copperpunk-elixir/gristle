defmodule Cluster.Network.NodeConnection do
  require Logger

  @spec get_unique_node_name_with_domain(tuple()) :: binary()
  def get_unique_node_name_with_domain(ip_address) do
    ip_address_string = VintageNet.IP.ip_to_string(ip_address)
    Logger.debug("#{ip_address_string}")
    UUID.uuid1 <> "@" <> ip_address_string
  end

  @spec start_node(binary(), atom()) :: atom()
  def start_node(node_name_with_domain, cookie) do
    Logger.debug("Node to start: #{String.to_atom(node_name_with_domain)}")
    :os.cmd('epmd -daemon')
    Node.start(String.to_atom(node_name_with_domain))
    Node.set_cookie(cookie)
  end

  # @spec open_socket_active(integer()) :: any()
  # def open_socket_active(port) do
  #   Logger.debug("open socken on port #{port}")
  #   {:ok, socket} = :gen_udp.open(port, [broadcast: true, active: true])
  #   Logger.debug(inspect(socket))
  #   socket
  # end

  @spec broadcast_node(any(), tuple(), binary(), integer()) :: atom()
  def broadcast_node(socket, ip_address, node_name_with_domain, dest_port) do
    # Logger.debug("Broadcast")
    # Logger.debug("host: #{inspect(ip_address)}")
    broadcast_address = {elem(ip_address,0), elem(ip_address,1), 7, 255}
      # put_elem(ip_address,3,255)
    # Logger.debug("address: #{inspect(broadcast_address)}")
    :gen_udp.send(socket, broadcast_address, dest_port, "connect:" <> node_name_with_domain)
  end

  @spec process_udp_message(any(), tuple(), integer(), binary(), tuple(), integer()) :: binary()
  def process_udp_message(socket, src_ip, src_port, msg, dest_ip, dest_port) do
    # Logger.debug("msg rx with socket #{inspect(socket)} from #{inspect(src_ip)} on port #{src_port}: #{msg}")
    msg = to_string(msg)
    if (String.contains?(msg,":")) do
      [msg_type, node] = String.split(msg,":")
      case msg_type do
        "connect" ->
          # Logger.warn("node #{node} wants to connect")
          if (src_ip != dest_ip) or (src_port != dest_port) do
            Logger.debug("Connect to node #{node}")
            Node.connect(String.to_atom(node))
            node
          else
            # Logger.warn("This is us. Do not connect")
            nil
          end
        _unknown ->
          Logger.warn("unknown msg_type: #{inspect(msg_type)}")
          nil
      end
    else
      Logger.warn("Unnown msg: #{inspect(msg)}")
      nil
    end
  end
end
