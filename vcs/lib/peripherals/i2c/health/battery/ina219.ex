defmodule Peripherals.I2c.Health.Battery.Ina219 do
  use Bitwise
  require Logger

  @device_address 0x48
  @reg_config 0x00
  @reg_bus_voltage 0x02
  @reg_current 0x04
  @reg_calibration 0x05
  @cal_value 4096

  @spec configure(any()) :: atom()
  def configure(i2c_ref) do
    set_mode(i2c_ref, @cal_value)
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    result = read_channel(i2c_ref, @reg_bus_voltage)
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
    result = read_channel(i2c_ref, @reg_current)
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
        # Logger.debug("msb/lsb: #{msb}/#{lsb}")
        output = ((msb<<<8) + lsb)
        {:ok, output}
      end
    else
      {:error, :bus_not_available}
    end
  end

  @spec set_mode(any(), integer()) :: atom()
  def set_mode(i2c_ref, cal_value) do
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_calibration>> <> <<cal_value::16>>)
    Process.sleep(5)
    brng = 1 # Bus Voltage Range (32V)
    pg = 3 # PGA gain/range (+/- 320mV)
    badc = 3 # Bus ADC Resolution/Averaging (12-bit)
    sadc = 3 # Shunt ADC Resolution/Averaging (12-bit 1S 532us)
    mode = 7 # Operating Mode (Shunt and Bus, Continuous)
    data = <<0::2,brng::1,pg::2, badc::4, sadc::4, mode::3>>
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_config>> <> data)
  end
end
