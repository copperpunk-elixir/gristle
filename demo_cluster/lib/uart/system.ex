defmodule Uart.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Uart Supervisor")
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(_config) do
    # children = Enum.reduce(config, [], fn({single_module, single_config}, acc) ->
    #   module = Module.concat(Peripherals.Uart, single_module)
    #   |> Module.concat(Operator)
    #   # Logger.debug("module: #{module}")
    #   # Logger.info("config: #{inspect(single_config)}")
    #   acc ++ [{module, single_config}]
    # end)
    children = [{Uart.Operator, Configuration.Uart.get_config(nil)}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
