defmodule Actuation.System do
  require Logger

  def start_link(config) do
    Logger.debug("Actuation Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    Supervisor.start_link(
      [
        {Actuation.HwInterface, config.hw_interface},
        {Actuation.SwInterface, config.sw_interface}
      ],
      strategy: :one_for_one
    )
  end
end
