defmodule Cluster.Network.Utils do
  require Logger

  @spec set_host_name() :: atom()
  def set_host_name() do
    host_name = Common.Utils.File.get_filenames_with_extension(".node") |> Enum.at(0)
    MdnsLite.set_host(host_name)
  end
end
