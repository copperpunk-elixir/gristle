defmodule Peripherals.I2c.Health.Battery.Ina219 do
  use Bitwise
  require Logger

  @device_address 0x48
  @reg_config 0x00
  @reg_bus_voltage 0x02
  @reg_current 0x04
  @reg_calibration 0x05

  @spec configure(any()) :: atom()
  def configure(_i2c_ref) do
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    # result = read_channel(i2c_ref, @reg_bus_voltage)
    result = {:ok, 8}
    case result do
      {:ok, voltage} ->
        Logger.debug("Ina219 voltage (raw): #{voltage}")
        (voltage>>>3)*4
      other ->
        Logger.error("Ina219 Voltage read error: #{inspect(other)}")
        nil
    end
  end

  @spec read_current(any()) :: float()
  def read_current(i2c_ref) do
    # result = read_channel(i2c_ref, @reg_current)
    result = {:ok, 2}
    case result do
      {:ok, current} ->
        Logger.debug("Ina219 current (raw): #{current}")
        current
      other ->
        Logger.error("Ina219 Current read error: #{inspect(other)}")
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
        Logger.debug("msb/lsb: #{msb}/#{lsb}")
        output = ((msb<<<8) + lsb)
        {:ok, output}
      end
    else
      {:error, :bus_not_available}
    end
  end
end
