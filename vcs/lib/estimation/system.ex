defmodule Estimation.System do
  require Logger

  def start_link(config) do
    Logger.debug("Estimation Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    Supervisor.start_link(
      [
        {Estimation.Estimator, config.estimator}
      ],
      strategy: :one_for_one
    )
  end
end
