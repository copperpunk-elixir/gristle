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
          # Check FrSky
          Logger.warn("#{interface_module} could not be reached. Checking for Frsky interface.")
          raise "#{interface_module} is unavailable"
        end
      interface -> interface
    end
  end


end
