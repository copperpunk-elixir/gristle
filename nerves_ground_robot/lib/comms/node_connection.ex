defmodule Comms.NodeConnection do
  require Logger

  @default_udp_port 8780 #arbitrary port

  def get_ip_address_tuple(interface) do
    Logger.debug("Get IP address")
    get_ip_address(interface)
  end

  def get_node_name_with_domain(node_name, ip_address_tuple) do
    ip_address_string = VintageNet.IP.ip_to_string(ip_address_tuple)
    Logger.debug("#{ip_address_string}")
    Atom.to_string(node_name) <> "@" <> ip_address_string
  end

  def start_node(node_name_with_domain, cookie) do
    Logger.debug("Node to start: #{String.to_atom(node_name_with_domain)}")
    :os.cmd('epmd -daemon')
    Node.start(String.to_atom(node_name_with_domain))
    Node.set_cookie(cookie)
  end

  def open_socket_active(port \\ @default_udp_port) do
    Logger.debug("open socken on port #{port}")
    {:ok, socket} = :gen_udp.open(port, [broadcast: true, active: true])
    Logger.debug(inspect(socket))
    socket
  end

  def open_socket_passive(port \\ @default_udp_port) do
    Logger.debug("open socken on port #{port}")
    {:ok, socket} = :gen_udp.open(port, [broadcast: true, active: false])
    Logger.debug(inspect(socket))
    socket
  end

  def broadcast_node(socket, ip_address_tuple, node_name_with_domain, port \\ @default_udp_port) do
    Logger.debug("Broadcast")
    Logger.debug("host: #{inspect(ip_address_tuple)}")
    broadcast_address = put_elem(ip_address_tuple,3,255)
    :gen_udp.send(socket, broadcast_address, port, "connect:" <> node_name_with_domain)
  end

  def process_udp_message(_socket, source_ip, _port, msg, dest_ip) do
    # Logger.debug("msg rx with socket #{inspect(socket)} from #{inspect(source_ip)} on port #{port}: #{msg}")
    msg = to_string(msg)
    if (String.contains?(msg,":")) do
      [msg_type, node] = String.split(msg,":")
      case msg_type do
        "connect" ->
          if (source_ip != dest_ip) do
            Logger.debug("Connect to node #{node}")
            Node.connect(String.to_atom(node))
          end
        _unknown ->
          Logger.warn("unknown msg_type: #{inspect(msg_type)}")
      end
    else
      Logger.warn("Unnown msg: #{inspect(msg)}")
    end
  end

  defp get_ip_address(interface) do
    ip_addresses = VintageNet.get(["interface", Atom.to_string(interface), "addresses"])
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
end
