defmodule Peripherals.Gpio.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Peripherals.Gpio start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = Enum.reduce(config, [], fn({single_module, single_config}, acc) ->
      module = Module.concat(Peripherals.Gpio, single_module)
      |> Module.concat(Operator)
      Logger.warn("module: #{module}")
      Logger.info("config: #{inspect(config)}")
      acc ++ [{module, single_config}]
    end)
    Supervisor.init(children, strategy: :one_for_one)
  end
end
