defmodule Cluster.Network.Utils do
  require Logger

  @spec set_host_name() :: atom()
  def set_host_name() do
    host_name = Common.Utils.Configuration.get_node_type()
    Logger.debug("Set Mdns host_name: #{host_name}")
    MdnsLite.set_host(host_name)
  end
end
