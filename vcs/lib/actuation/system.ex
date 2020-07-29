defmodule Actuation.System do
  require Logger
  use Supervisor

  def start_link(config) do
    Logger.debug("Actuation Supervisor start_link()")
    # config = Configuration.Module.Actuation.get_config(vehicle_type, node_type)
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = [
      Supervisor.child_spec({Actuation.HwInterface, config.hw_interface}, id: Actuation.HwInterface),
      Supervisor.child_spec({Actuation.SwInterface, config.sw_interface}, id: Actuation.SwInterface)
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
