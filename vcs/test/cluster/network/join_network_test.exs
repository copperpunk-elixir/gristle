defmodule Cluster.Network.JoinNetworkTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    network_config = %{
      is_embedded: false,
      interface: "wlp0s20f3",
      broadcast_ip_loop_interval_ms: 1000,
      cookie: :monster,
      port: 8780
    }
    Cluster.Network.start_link(network_config)
    Process.sleep(100)
    {:ok, []}
  end

  test "Get IP address" do
    ip_address = Cluster.Network.get_ip_address()
    assert ip_address == {192,168,4,32}
    Process.sleep(300000)
  end
end
