defmodule Peripherals.I2c.Health.Battery.Ina260 do
  use Bitwise
  require Logger

  @device_address 0x40
  @reg_config 0x00
  @reg_current 0x01
  @reg_voltage 0x02

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    # result = read_channel(i2c_ref, @reg_voltage)
    result = {:ok, 3.0}
    case result do
      {:ok, voltage} ->
        # Logger.debug("Ina260 voltage: #{voltage}")
        voltage
      other ->
        Logger.error("Ina260 Voltage read error: #{inspect(other)}")
        nil
    end
  end

  @spec read_current(any()) :: float()
  def read_current(i2c_ref) do
    # result = read_channel(i2c_ref, @reg_current)
    result = {:ok, 2.0}
    case result do
      {:ok, current} ->
        # Logger.debug("Ina260 current: #{current}")
        current
      other ->
        Logger.error("Ina260 Current read error: #{inspect(other)}")
        nil
    end
  end

  @spec read_channel(any(), integer()) :: tuple()
  def read_channel(i2c_ref, channel) do
    {msg, result} = Circuits.I2C.write_read(i2c_ref, @device_address, <<channel>>, 2)
    if msg == :ok do
      if result == "" do
        {:error, :bad_ack}
      else
        <<msb, lsb>> = result
        output = ((msb<<<8) + lsb)*0.00125
        {:ok, output}
      end
    else
      {:error, :bus_not_available}
    end
  end
end
