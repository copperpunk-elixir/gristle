defmodule Navigation.System do
  require Logger

  def start_link(config) do
    Logger.info("Navigation Supervisor start_link()")
    Comms.System.start_link()
    children = [{Navigation.PathPlanner, config.path_planner}]
    children =
      case config.node_type do
        :gcs -> children
        _other ->
          children ++
            [
              {Navigation.Navigator, config.navigator},
              {Navigation.PathManager, config.path_manager}
            ]
      end
    Supervisor.start_link(
      children,
      strategy: :one_for_one
    )
  end
end
