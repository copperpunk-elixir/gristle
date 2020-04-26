defmodule Swarm.System do
  require Logger

  def start_link(config) do
    Logger.debug("Swarm Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    hb_config = Map.get(config, :heartbeat, %{})
    gsm_config = Map.get(config, :gsm, %{})
    Supervisor.start_link(
      [
        {Swarm.Heartbeat, hb_config},
        {Swarm.Gsm, gsm_config}
      ],
      strategy: :one_for_one
    )
  end

  def start_link() do
    start_link(%{})
  end
end
