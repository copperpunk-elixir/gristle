defmodule Cluster.System do
  require Logger

  def start_link(config) do
    Logger.debug("Cluster Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    hb_config = Map.get(config, :heartbeat, %{})
    gsm_config = Map.get(config, :gsm, %{})
    Supervisor.start_link(
      [
        {Cluster.Heartbeat, hb_config},
        {Cluster.Gsm, gsm_config}
      ],
      strategy: :one_for_one
    )
  end

  def start_link() do
    start_link(%{})
  end
end
