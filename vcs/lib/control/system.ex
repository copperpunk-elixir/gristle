defmodule Control.System do
  require Logger

  def start_link(config) do
    Logger.info("Control Supervisor start_link()")
    Comms.System.start_link()
    Supervisor.start_link(
      [
        {Control.Controller, config.controller}
      ],
      strategy: :one_for_one
    )
  end
end
