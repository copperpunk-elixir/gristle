defmodule Command.System do
  require Logger

  def start_link(config) do
    Logger.debug("Command Supervisor start_link()")
    Comms.ProcessRegistry.start_link()
    Supervisor.start_link(
      [
        {Command.Commander, config.commander},
        {Peripherals.Uart.FrskyRx, config.frsky_rx}
      ],
      strategy: :one_for_one
    )
  end
end
