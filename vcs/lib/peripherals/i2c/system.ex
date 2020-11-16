defmodule Peripherals.I2c.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Peripherals.I2c start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = Enum.reduce(config, [], fn({single_module, single_config}, acc) ->
      module = Module.concat(Peripherals.I2c, single_module)
      |> Module.concat(Operator)
      Logger.debug("module: #{module}")
      acc ++ [Supervisor.child_spec({module, single_config}, id: Module.concat(module, single_config[:module]))]
    end)
    Supervisor.init(children, strategy: :one_for_one)
  end
end
