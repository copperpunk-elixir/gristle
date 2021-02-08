defmodule Gcs.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Gcs Supervisor")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Gcs.Operator, config[:operator]},
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
