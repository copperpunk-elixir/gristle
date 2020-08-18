defmodule Peripherals.Uart.System do
  require Logger

  def start_link(config) do
    Logger.info("Peripherals.Uart start_link()")
    Comms.System.start_link()
    children = Enum.reduce(config, [], fn({single_module, single_config}, acc) ->
      module = Module.concat(Peripherals.Uart, single_module)
      Logger.warn("module: #{module}")
      Logger.info("config: #{inspect(config)}")
      acc ++ [{module, single_config}]
    end)
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
