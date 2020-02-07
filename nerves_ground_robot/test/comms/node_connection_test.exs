defmodule Comms.NodeConnectionTest do
  use ExUnit.Case
  doctest Comms.NodeConnection

  test "Node Connection tests" do
    ip_address_tuple = {192, 168, 86, 24}
    node_name = :master
    assert Comms.NodeConnection.get_node_name_with_domain(node_name, ip_address_tuple) == "master@192.168.86.24"

    # Get actual IP address
    # interface = :wlan0 # use with RPi
    interface = :wlp0s20f3 # use with System76
    ip_address_tuple = Comms.NodeConnection.get_ip_address_tuple(interface)
    assert is_tuple(ip_address_tuple) == true

    # Start Node
    node_name = :master
    cookie = :monster
    node_name_with_domain = Comms.NodeConnection.get_node_name_with_domain(node_name, ip_address_tuple)
    Comms.NodeConnection.start_node(node_name_with_domain, cookie)
    node_self_string = Atom.to_string(Node.self())
    assert String.contains?(node_self_string, Atom.to_string(node_name)) == true
    assert Node.get_cookie == cookie

    # Open udp socket
    udp_port = 8000
    socket = Comms.NodeConnection.open_socket_passive(udp_port)
    assert socket != nil
    Comms.NodeConnection.broadcast_node(socket, ip_address_tuple, node_name_with_domain, udp_port)
    {:ok, message} = :gen_udp.recv(socket, 1, 100)
    assert elem(message,0) == ip_address_tuple
    assert elem(message,1) == udp_port
    message_string = to_string(elem(message, 2))
    assert message_string == "connect:" <> node_name_with_domain
  end
end
