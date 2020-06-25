defmodule Navigation.System do
  require Logger

  def start_link(config) do
    Logger.debug("Navigation Supervisor start_link()")
    Comms.System.start_link()
    Supervisor.start_link(
      [
        {Navigation.Navigator, config.navigator},
        {Navigation.PathManager, config.path_manager}
      ],
      strategy: :one_for_one
    )
  end
end
