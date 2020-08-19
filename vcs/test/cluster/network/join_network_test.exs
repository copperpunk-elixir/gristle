defmodule Cluster.Network.JoinNetworkTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach
    Logging.System.start_link(Configuration.Module.get_config(Logging, nil, nil))
    Comms.System.start_link()
    Process.sleep(100)
    network_config = Configuration.Module.Cluster.get_network_config()
    Cluster.Network.start_link(network_config)
    Process.sleep(1000)
    {:ok, []}
  end

  test "Connect to wireless network" do
    # interface = "wlp0s20f3"
    connection_status = Cluster.Network.connected_to_network?()
    if connection_status == false do
      Logger.warn("network not connected")
      Process.sleep(10000)
    end
    connection_status = Cluster.Network.connected_to_network?()
    assert connection_status == true
  end

  # test "Get IP address" do
  #   # This is a visual test. It requires to instances of a terminal.
  #   # Verify that the Nodes connect to each other succesfully.
  #   ip_address = Cluster.Network.get_ip_address()
  #   assert ip_address == {192,168,4,32}
  #   Process.sleep(5000)
  # end
end
