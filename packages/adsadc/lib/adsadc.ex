defmodule Adsadc do
  @moduledoc """
  Documentation for Sparkfun 12-bit ADC.
  Configures the ADC to capture measurements continuously at 1600 Hz.
  This package was created to enable the use of a two-axis analog joystick
  """

  @doc """
  """
  use Bitwise
  require Logger
  defstruct [bus_ref: nil, address: nil, input_method: nil]

  @default_bus "i2c-1"
  @default_address 0x48
  @default_input_method :exponential

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

  @doc """
  Instantiate new `Adsadc` struct

  `config` is a map that can contain the following fields

  `bus_ref` - The I2C bus (default `"i2c-1"`)

  `address` - The address of the adsadc board (default `0x48`)

  `input_method` - `:linear`, `:exponential` (default `:exponential`)
  """
  @spec new_adsadc(map) :: %Adsadc{}
  def new_adsadc(config) do
    Logger.debug("Start Ads ADC")
    bus_ref = Adsadc.Utils.get_bus_ref(Map.get(config, :i2c_bus, @default_bus))
    address = Map.get(config, :address, @default_address)
    input_method = Map.get(config, :input_method, @default_input_method)
    # channels = config.channels
    %Adsadc{bus_ref: bus_ref, address: address, input_method: input_method}
  end


  @doc """
  Read the output for a given adsadc struct
  The output is a `float` in the range `[-1.0, 1.0]`
  """
  @spec read_device_channel(%Adsadc{}, integer) :: float
  def read_device_channel(device, channel) do
    # IO.puts("read channel: #{inspect(channel)}")
    result = read_channel(device.bus_ref, device.address, device.input_method, channel.pin)
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

  defp read_channel(bus_ref, address, input_method, pin) do
    config = @config_os_single ||| @config_mode_cont ||| @config_rate_1600_hz
    config = config ||| @config_pga_1
    config = config ||| (@config_mux_single_0 + (pin <<< 12))
    # IO.puts("config: #{config}")
    # require IEx; IEx.pry
    data = [@pointer_config, config >>> 8, config &&& 0xFF]
    # IO.puts("write data: #{data}")
    Adsadc.Utils.write_packet(bus_ref, address, data)
    Process.sleep(1)
    value = Adsadc.Utils.write_read(bus_ref, address, @pointer_convert, 2)
    if value == [] do
      {:error, :bad_ack}
    else
      msb = Enum.at(value, 0) <<< 8
      lsb = Enum.at(value, 1)
      total = ((msb ||| lsb) >>> 4)*@counts2output - 1.0
      # IO.puts("msb/lsb/total: #{msb}/#{lsb}/#{total}")
      output =
        case input_method do
          :linear -> total
          :exponential ->
            if (total < 0) do
              -(total*total)
            else
              total*total
            end
        end
      {:ok, output}
    end
  end

  def hello do
    :world
  end

  def get_hello_function() do
    (fn recip ->
      "Hello to #{recip}"
    end)
  end
end
