defmodule Navigation.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Navigation Supervisor start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    # children = [{Navigation.PathPlanner, config.path_planner}]
    children =
      case config.node_type do
        :gcs -> []
        _other ->
            [
              {Navigation.Navigator, config.navigator},
              {Navigation.PathManager, config.path_manager}
            ]
      end
    Supervisor.init(children, strategy: :one_for_one)
  end
end
