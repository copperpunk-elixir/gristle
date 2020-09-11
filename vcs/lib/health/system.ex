defmodule Health.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Health Supervisor start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Health.Power, config.power}
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
