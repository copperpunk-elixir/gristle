defmodule Cluster.System do
  require Logger

  def start_link(config) do
    Logger.debug("Cluster Supervisor start_link()")
    Comms.System.start_link()
    Supervisor.start_link(
      [
        {Cluster.Heartbeat, config.heartbeat},
        {Cluster.Network, config.network}
      ],
      strategy: :one_for_one
    )
  end

  def start_link() do
    start_link(%{})
  end
end
