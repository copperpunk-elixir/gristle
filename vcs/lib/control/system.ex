defmodule Control.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Control Supervisor")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Control.Controller, config[:controller]}
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
