defmodule Peripherals.I2c.Health.Battery.Ina260 do
  use Bitwise
  require Logger

  @device_address 0x40
  @reg_config 0x00
  @reg_current 0x01
  @reg_voltage 0x02

  @spec configure(any()) :: atom()
  def configure(i2c_ref) do
    Logger.debug("configure Ina260")
    set_mode(i2c_ref)
    Process.sleep(100)
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    result = read_channel(i2c_ref, @reg_voltage)
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
    result = read_channel(i2c_ref, @reg_current)
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

  @spec set_mode(any()) :: atom()
  def set_mode(i2c_ref) do
    avg_mode = 3 # 64 samples
    bus_volt_conv = 4 # 1.1ms (default)
    shunt_cur_conv = 4 # 1.1ms (default)
    op_mode = 7 # Continuous (default)
    data = <<0::1,6::3,avg_mode::3,bus_volt_conv::3,shunt_cur_conv::3,op_mode::3>>
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_config>> <> data)
  end

  @spec reset(any()) :: atom()
  def reset(i2c_ref) do
    data = <<1::1,0::15>>
    Circuits.I2C.write(i2c_ref, @device_address, <<@reg_config>> <> data)
  end
end
