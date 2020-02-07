defmodule Sensors.Uart.Utils do
  alias Circuits.UART
  require Logger

  def get_uart_ref do
    {:ok, ref} = UART.start_link
    ref
  end

  def open_defaults(pid, port) do
    open_active(pid, port, 115200)
  end

  def open_active(pid, port, speed) do
    UART.open(pid, port, [speed: speed, active: true])
  end

  def open_passive(pid, port, speed) do
    UART.open(pid, port, [speed: speed, active: false])
  end

  def read(pid, timeout) do
    # IO.puts("read: #{inspect(pid)}")
    case UART.read(pid, timeout) do
      {:ok, binary} ->
        # Logger.debug("Good read: #{binary}")
        :binary.bin_to_list(binary)
      {msg, _} ->
        Logger.debug("No read: #{msg}")
        []
    end
  end

  def write(pid, data, timeout) do
    UART.write(pid, data, timeout)
  end

  def write_defaults(pid, data) do
    write(pid, data, 5000)
  end
end
