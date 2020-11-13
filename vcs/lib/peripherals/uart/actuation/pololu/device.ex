defmodule Peripherals.Uart.Actuation.Pololu.Device do
  require Bitwise
  require Logger

  @enforce_keys [:interface_ref]
  defstruct [interface_ref: nil, write_timeout: 1, read_timeout: 1]

  def new_device(interface_ref) do
    %Peripherals.Uart.Actuation.Pololu.Device{interface_ref: interface_ref}
  end

  def write_microseconds(device, channel, output_ms) do
    # See Pololu Maestro Servo Controller User's Guide for explanation
    message = get_message_for_channel_and_output_ms(channel, output_ms)
    # Logger.debug("set #{channel} to #{Common.Utils.eftb(output_ms,0)}")
    :ok = Circuits.UART.write(device.interface_ref, :binary.list_to_bin(message), device.write_timeout)
  end

  def get_message_for_channel_and_output_ms(channel, output_ms) do
    target = round(output_ms * 4) # 1/4us resolution
    lsb = Bitwise.&&&(target, 0x7F)
    msb = Bitwise.>>>(target, 7) |> Bitwise.&&&(0x7F)
    packet = [0x84, channel, lsb, msb]
    packet ++ [get_checksum_for_packet(packet)]
  end

  def get_output_for_channel_number(device, channel) do
    packet = [0x90, channel]
    message = packet ++ [get_checksum_for_packet(packet)]
    Circuits.UART.write(device.interface_ref, :binary.list_to_bin(message), device.write_timeout)
    response = read_to_list(device.interface_ref, device.read_timeout)
    if length(response) == 2 do
      (Bitwise.<<<(Enum.at(response, 1),8) |> Bitwise.bor(Enum.at(response, 0))) / 4
    else
      nil
    end
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

  def read_to_list(interface_ref, timeout) do
    case Circuits.UART.read(interface_ref, timeout) do
      {:ok, binary} ->
        # Logger.debug("Good read: #{binary}")
        :binary.bin_to_list(binary)
      {msg, _} ->
        Logger.debug("No read: #{msg}")
        []
    end
  end

  @spec write_channels(struct(), map()) :: atom()
  def write_channels(device, channels) do
    Enum.each(channels, fn{channel_number, value} ->
      unless is_nil(value) do
        write_microseconds(device, channel_number, value)
      end
    end)
  end

  @spec set_interface_ref(struct(), any()) :: atom()
  def set_interface_ref(device, interface_ref) do
    %{device | interface_ref: interface_ref}
  end
end
