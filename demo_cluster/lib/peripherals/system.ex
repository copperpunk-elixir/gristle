defmodule Peripherals.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Peripherals Supervisor")
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = [
      {Peripherals.Uart.Operator, config[:uart]},
      {Peripherals.Gpio.Operator, config[:gpio]},
      {Peripherals.I2c.Operator, config[:i2c]},
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
