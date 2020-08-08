defmodule Telemetry.System do
  require Logger

  def start_link(config) do
    Logger.info("Telemetry Supervisor start_link()")
    Comms.System.start_link()
    Supervisor.start_link(
      [
        {Telemetry.Operator, config.operator}
      ],
      strategy: :one_for_one
    )
  end
end
