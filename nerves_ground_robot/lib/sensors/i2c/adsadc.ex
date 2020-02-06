defmodule Sensors.I2c.Adsadc do
  use Bitwise
  defstruct [bus_ref: nil, address: nil]

  @default_bus "i2c-1"
  @default_address 0x48
  @config_os_single 0x8000
  @config_mode_cont 0x0000
  @config_mux_single_0 0x4000
  # @config_rate_250hz 0x0020
  @config_rate_1600_hz 0x0080
  @pointer_config 0x01
  @pointer_convert 0
  @config_pga_1 0x0200
  # @config_pga_2 0x0400

  @counts2output 4.0/3300 #output is [-1, 1]

  def new_adsadc(config) do
    IO.puts("Start Ads ADC")
    bus_ref = Sensors.I2c.Utils.get_bus_ref(Map.get(config, :i2c_bus, @default_bus))
    address = Map.get(config, :address, @default_address)
    # channels = config.channels
    %Sensors.I2c.Adsadc{bus_ref: bus_ref, address: address}
  end

  # def read_all_channels(%Sensors.I2c.Adsadc{bus_ref: bus_ref, address: address, channels: channels}) do
  #   output_all_channels = Enum.reduce(channels, %{}, fn ({_channel, config}, acc) ->
  #     output = read_channel(bus_ref, address, config.pin)
  #     output =
  #     if config.inverted do
  #       -output
  #     else
  #       output
  #     end
  #     Map.put(acc, config.cmd, output)
  #   end)
  #   output_all_channels
  # end

  def read_channel(device, channel) do
    # IO.puts("read channel: #{inspect(channel)}")
    result = read_channel(device.bus_ref, device.address, channel.pin)
    case result do
      {:ok, value} ->
        if channel.inverted do
          {:ok, -value}
        else
          {:ok, value}
        end
      _error -> "Bad read_channel"
    end
  end

  defp read_channel(bus_ref, address, pin) do
    config = @config_os_single ||| @config_mode_cont ||| @config_rate_1600_hz
    config = config ||| @config_pga_1
    config = config ||| (@config_mux_single_0 + (pin <<< 12))
    # IO.puts("config: #{config}")
    # require IEx; IEx.pry
    data = [@pointer_config, config >>> 8, config &&& 0xFF]
    # IO.puts("write data: #{data}")
    Sensors.I2c.Utils.write_packet(bus_ref, address, data)
    Process.sleep(1)
    value = Sensors.I2c.Utils.write_read(bus_ref, address, @pointer_convert, 2)
    if value == [] do
      {:error, :bad_ack}
    else
      msb = Enum.at(value, 0) <<< 8
      lsb = Enum.at(value, 1)
      total = ((msb ||| lsb) >>> 4)*@counts2output - 1.0
      # IO.puts("msb/lsb/total: #{msb}/#{lsb}/#{total}")
      output =
      if (total < 0) do
        -(total*total)
      else
        total*total
      end
      {:ok, output}
    end
  end

end
