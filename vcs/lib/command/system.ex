defmodule Command.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Command Supervisor")
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = [{Command.Commander, config[:commander]}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
