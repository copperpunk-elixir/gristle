defmodule Peripherals.Uart.Utils do
  require Logger
  @spec open_interface_connection(atom(), any(), integer(), integer()) :: any()
  def open_interface_connection(interface_module, interface, connection_count, connection_count_max) do
    case apply(interface_module, :open_port, [interface]) do
      nil ->
        if (connection_count < connection_count_max) do
          Logger.warn("#{interface_module} is unavailable. Retrying in 1 second.")
          Process.sleep(1000)
          open_interface_connection(interface_module, interface, connection_count+1, connection_count_max)
        else
          raise "#{interface_module} is unavailable"
        end
      interface -> interface
    end
  end

  @spec get_uart_devices_containing_string(binary()) :: list()
  def get_uart_devices_containing_string(device_string) do
    device_string = String.downcase(device_string)
    Logger.debug("devicestring: #{device_string}")
    uart_ports = Circuits.UART.enumerate()
    Logger.debug("ports: #{inspect(uart_ports)}")
    matching_ports = Enum.reduce(uart_ports, [], fn ({port_name, port}, acc) ->
      device_description = Map.get(port, :description,"")
      Logger.debug("description: #{String.downcase(device_description)}")
      if String.contains?(String.downcase(device_description), device_string) do
        acc ++ [port_name]
      else
        acc
      end
    end)
    case length(matching_ports) do
      0 -> nil
      _ -> Enum.min(matching_ports)
    end
  end
end
