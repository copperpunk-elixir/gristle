defmodule Peripherals.Uart.Actuation.Frsky.Device do
  require Bitwise
  require Logger

  @enforce_keys [:interface_ref]
  defstruct [interface_ref: nil, write_timeout: 1, read_timeout: 1]

  def new_device(interface_ref) do
    %Peripherals.Uart.Actuation.Frsky.Device{interface_ref: interface_ref}
  end

  def get_output_for_channel_number(_device, _channel) do
    nil
  end

  def get_checksum_for_packet(packet) do
    packet_length = length(packet)
    # https://www.pololu.com/docs/0J40/5.d
    {message_sum, _} = Enum.reduce(packet,{0,0}, fn (byte, acc)->
      {elem(acc, 0) + Bitwise.<<<(byte,8*elem(acc,1)), elem(acc,1)+1}
    end )
    crc_poly = 0x91
    crc = Enum.reduce(1..8*packet_length, message_sum, fn (_step, acc) ->
      acc =
      if Bitwise.band(acc, 1) == 1 do
        Bitwise.bxor(crc_poly, acc)
      else
        acc
      end
      # Logger.debug("Step/message: #{step}, #{acc}")
      Bitwise.>>>(acc,1)
    end)
    # flip the bits
    Bitwise.band(crc, 0x7F)
  end

  @spec write_channels(struct(), map()) :: atom()
  def write_channels(device, channels) do
    channels = Enum.reduce(channels, %{}, fn ({key, value},acc) ->
      if (is_nil(value)), do: acc, else: Map.put(acc, key, round(value))
    end)
    #Logger.info("ch: #{Common.Utils.eftb_map(channels, 0)}")
    # Logger.debug("update flap: #{Map.get(channels,4)}")
    # Logger.debug("update gear: #{Map.get(channels,5)}")
    header = 0x0F
    b1 = Bitwise.&&&(Map.get(channels,0,0), 0xFF)

    b2a = Bitwise.&&&(Map.get(channels,0,0), 0x7FF) |> Bitwise.>>>(8) |> Bitwise.&&&(0xFF)
    b2b = Bitwise.&&&(Map.get(channels,1,0), 0x7FF) |> Bitwise.<<<(3) |> Bitwise.&&&(0xFF)
    b2 = Bitwise.|||(b2a, b2b)

    b3a = Bitwise.&&&(Map.get(channels,1,0), 0x7FF) |> Bitwise.>>>(5) |> Bitwise.&&&(0xFF)
    b3b = Bitwise.&&&(Map.get(channels,2,0), 0x7FF) |> Bitwise.<<<(6) |> Bitwise.&&&(0xFF)
    b3 = Bitwise.|||(b3a, b3b)

    b4 = Bitwise.&&&(Map.get(channels,2,0), 0x7FF) |> Bitwise.>>>(2) |> Bitwise.&&&(0xFF)

    b5a = Bitwise.&&&(Map.get(channels,2,0), 0x7FF) |> Bitwise.>>>(10) |> Bitwise.&&&(0xFF)
    b5b = Bitwise.&&&(Map.get(channels,3,0), 0x7FF) |> Bitwise.<<<(1) |> Bitwise.&&&(0xFF)
    b5 = Bitwise.|||(b5a, b5b)

    b6a = Bitwise.&&&(Map.get(channels,3,0), 0x7FF) |> Bitwise.>>>(7) |> Bitwise.&&&(0xFF)
    b6b = Bitwise.&&&(Map.get(channels,4,0), 0x7FF) |> Bitwise.<<<(4) |> Bitwise.&&&(0xFF)
    b6 = Bitwise.|||(b6a, b6b)

    b7a = Bitwise.&&&(Map.get(channels,4,0), 0x7FF) |> Bitwise.>>>(4) |> Bitwise.&&&(0xFF)
    b7b = Bitwise.&&&(Map.get(channels,5,0), 0x7FF) |> Bitwise.<<<(7) |> Bitwise.&&&(0xFF)
    b7 = Bitwise.|||(b7a, b7b)

    b8 = Bitwise.&&&(Map.get(channels,5,0), 0x7FF) |> Bitwise.>>>(1) |> Bitwise.&&&(0xFF)

    b9a = Bitwise.&&&(Map.get(channels,5,0), 0x7FF) |> Bitwise.>>>(9) |> Bitwise.&&&(0xFF)
    b9b = Bitwise.&&&(Map.get(channels,6,0), 0x7FF) |> Bitwise.<<<(2) |> Bitwise.&&&(0xFF)
    b9 = Bitwise.|||(b9a, b9b)

    b10a = Bitwise.&&&(Map.get(channels,6,0), 0x7FF) |> Bitwise.>>>(6) |> Bitwise.&&&(0xFF)
    b10b = Bitwise.&&&(Map.get(channels,7,0), 0x7FF) |> Bitwise.<<<(5) |> Bitwise.&&&(0xFF)
    b10 = Bitwise.|||(b10a, b10b)

    b11 = Bitwise.&&&(Map.get(channels,7,0), 0x7FF) |> Bitwise.>>>(3) |> Bitwise.&&&(0xFF)

    b12 = Bitwise.&&&(Map.get(channels,8,0), 0xFF)

    b13a = Bitwise.&&&(Map.get(channels,8,0), 0x7FF) |> Bitwise.>>>(8) |> Bitwise.&&&(0xFF)
    b13b = Bitwise.&&&(Map.get(channels,9,0), 0x7FF) |> Bitwise.<<<(3) |> Bitwise.&&&(0xFF)
    b13 = Bitwise.|||(b13a, b13b)

    b14a = Bitwise.&&&(Map.get(channels,9,0), 0x7FF) |> Bitwise.>>>(5) |> Bitwise.&&&(0xFF)
    b14b = Bitwise.&&&(Map.get(channels,10,0), 0x7FF) |> Bitwise.<<<(6) |> Bitwise.&&&(0xFF)
    b14 = Bitwise.|||(b14a, b14b)

    b15 = Bitwise.&&&(Map.get(channels,10,0), 0x7FF) |> Bitwise.>>>(2) |> Bitwise.&&&(0xFF)

    b16a = Bitwise.&&&(Map.get(channels,10,0), 0x7FF) |> Bitwise.>>>(10) |> Bitwise.&&&(0xFF)
    b16b = Bitwise.&&&(Map.get(channels,11,0), 0x7FF) |> Bitwise.<<<(1) |> Bitwise.&&&(0xFF)
    b16 = Bitwise.|||(b16a, b16b)

    b17a = Bitwise.&&&(Map.get(channels,11,0), 0x7FF) |> Bitwise.>>>(7) |> Bitwise.&&&(0xFF)
    b17b = Bitwise.&&&(Map.get(channels,12,0), 0x7FF) |> Bitwise.<<<(4) |> Bitwise.&&&(0xFF)
    b17 = Bitwise.|||(b17a, b17b)

    b18a = Bitwise.&&&(Map.get(channels,12,0), 0x7FF) |> Bitwise.>>>(4) |> Bitwise.&&&(0xFF)
    b18b = Bitwise.&&&(Map.get(channels,13,0), 0x7FF) |> Bitwise.<<<(7) |> Bitwise.&&&(0xFF)
    b18 = Bitwise.|||(b18a, b18b)

    b19 = Bitwise.&&&(Map.get(channels,13,0), 0x7FF) |> Bitwise.>>>(1) |> Bitwise.&&&(0xFF)

    b20a = Bitwise.&&&(Map.get(channels,13,0), 0x7FF) |> Bitwise.>>>(9) |> Bitwise.&&&(0xFF)
    b20b = Bitwise.&&&(Map.get(channels,14,0), 0x7FF) |> Bitwise.<<<(2) |> Bitwise.&&&(0xFF)
    b20 = Bitwise.|||(b20a, b20b)

    b21a = Bitwise.&&&(Map.get(channels,14,0), 0x7FF) |> Bitwise.>>>(6) |> Bitwise.&&&(0xFF)
    b21b = Bitwise.&&&(Map.get(channels,15,0), 0x7FF) |> Bitwise.<<<(5) |> Bitwise.&&&(0xFF)
    b21 = Bitwise.|||(b21a, b21b)

    b22 = Bitwise.&&&(Map.get(channels,15,0), 0x7FF) |> Bitwise.>>>(3) |> Bitwise.&&&(0xFF)

    buffer = <<header, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, 0, 0>>
    # Logger.debug("write buffer: #{buffer}")
    unless is_nil(device) do
      Circuits.UART.write(device.interface_ref, buffer, device.write_timeout)
#      Circuits.UART.drain(device.interface_ref)
    end
  end
end
