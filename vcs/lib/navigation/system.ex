defmodule Navigation.System do
  require Logger

  def start_link(config) do
    Logger.debug("Navigation Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    Supervisor.start_link(
      [
        {Navigation.Navigator, config.navigator}
      ],
      strategy: :one_for_one
    )
  end
end
