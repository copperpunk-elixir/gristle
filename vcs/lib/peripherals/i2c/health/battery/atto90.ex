defmodule Peripherals.I2c.Health.Battery.Atto90 do
  use Bitwise
  require Logger

  @device_address 0x48
  @config_os_single 0x8000
  @config_mode_cont 0x0000
  @config_mux_single_0 0x4000
  @config_rate_128_hz 0x0000
  # @config_rate_1600_hz 0x0080
  @pointer_config 1
  @pointer_convert 0
  @config_pga_1 0x0200
  # @config_pga_2 0x0400

  @counts2output 2.0 #output is in mV
  # @output2volts 0.00412712
  # @output2amps 0.0136612

  @voltage_mult 0.015701052
  @current_mult 0.027322404

  @channel_voltage 0
  @channel_current 1

  @spec configure(any()) :: atom()
  def configure(_i2c_ref) do
  end

  @spec read_voltage(any()) :: float()
  def read_voltage(i2c_ref) do
    result = read_channel(i2c_ref, @channel_voltage)
    case result do
      {:ok, output} ->
        # Logger.debug("Atto90 voltage: #{output*output2volts}")
        output*@voltage_mult
      _other ->
        Logger.error("Voltage read error")
        nil
    end
  end

  @spec read_current(any()) :: float()
  def read_current(i2c_ref) do
    result = read_channel(i2c_ref, @channel_current)
    case result do
      {:ok, current} ->
        # Logger.debug("Atto90 current: #{current*output2amps}")
        current*@current_mult
      _other ->
        Logger.error("Current read error")
        nil
    end
  end

  @spec read_channel(any(), integer()) :: tuple()
  def read_channel(i2c_ref, channel) do
    config = @config_os_single ||| @config_mode_cont ||| @config_rate_128_hz
    config = config ||| @config_pga_1
    config = config ||| (@config_mux_single_0 + (channel <<< 12))
    # require IEx; IEx.pry
    data = <<@pointer_config, config >>> 8, config &&& 0xFF>>
    # IO.puts("write data: #{data}")
    Circuits.I2C.write(i2c_ref, @device_address, data)
    Process.sleep(20)
    {msg, result} = Circuits.I2C.write_read(i2c_ref, @device_address, <<@pointer_convert>>, 2)
    # Logger.debug("value: #{inspect(result)}")
    if msg == :ok do
      if result == "" do
      {:error, :bad_ack}
      else
        <<msb, lsb>> = result
        output = (((msb <<< 8) + lsb) >>> 4)*@counts2output
        {:ok, output}
      end
    else
      {:error, :bus_not_available}
    end
  end
end
