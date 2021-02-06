defmodule Estimation.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Estimation Supervisor")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Estimation.Estimator, config[:estimator]}
      ]
    # Logger.info("estimator children: #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_one)
  end
end
