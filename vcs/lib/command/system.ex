defmodule Command.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Command Supervisor start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = Enum.reduce(config.children, [], fn (child, acc) ->
      {module, _args} = child
      [Supervisor.child_spec(child, id: module)] ++ acc
    end)
    children = [{Command.Commander, config.commander}] ++ children
    Supervisor.init(children, strategy: :one_for_one)

  end
end
