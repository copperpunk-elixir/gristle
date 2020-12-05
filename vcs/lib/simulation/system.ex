defmodule Simulation.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Simulation Supervisor start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        # {Simulation.XplaneReceive, config[:receive]},
        # {Simulation.XplaneSend, config[:send]},
        {Simulation.Realflight, config[:realflight]}
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
