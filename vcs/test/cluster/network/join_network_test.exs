defmodule Cluster.Network.JoinNetworkTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    network_config = Configuration.Generic.get_network_config()
    Cluster.Network.start_link(network_config)
    Process.sleep(100)
    {:ok, []}
  end

  test "Connect to network" do
    interface = "wlp0s20f3"
    connection_status = VintageNet.get(["interface", interface, "lower_up"])
    if connection_status == false do
      Process.sleep(10000)
    end
    connection_status = VintageNet.get(["interface", interface, "lower_up"])
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
