defmodule Simulation.System do
  require Logger

  def start_link(config) do
    Logger.debug("Estimation Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    Supervisor.start_link(
      [
        {Simulation.XplaneReceive, config.receive},
        {Simulation.XplaneSend, config.send}
      ],
      strategy: :one_for_one
    )
  end
end
