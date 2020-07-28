defmodule Logging.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Logging Supervisor start_link()")
    Comms.System.start_link()
    Supervisor.start_link(
      [
        {Logging.Logger, config.logger}
      ],
      strategy: :one_for_one
    )
  end
end
