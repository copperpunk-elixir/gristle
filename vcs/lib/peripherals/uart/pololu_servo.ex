defmodule Peripherals.Uart.PololuServo do
  require Bitwise
  require Logger

  @default_baud 115_200
  @default_write_timeout 10
  @default_read_timeout 10

  defstruct [interface_ref: nil, baud: nil]

  def new_device(config) do
    baud = Map.get(config, :baud, @default_baud)
    {:ok, interface_ref} = Circuits.UART.start_link()
    %Peripherals.Uart.PololuServo{interface_ref: interface_ref, baud: baud}
  end

  def open_port(device) do
    Logger.debug("Open port with device: #{inspect(device)}")
    uart_ports = Circuits.UART.enumerate()
    pololu_ports = Enum.reduce(uart_ports, [], fn ({port_name, port}, acc) ->
      device_description = Map.get(port, :description)
      if (device_description != nil) && String.contains?(String.downcase(device_description), "pololu") do
        acc ++ [port_name]
      else
        acc
      end
    end)
    command_port =
      case length(pololu_ports) do
        0 -> nil
        _ -> Enum.min(pololu_ports)
      end
    Logger.debug("Pololu command port: #{command_port}")
    # Logger.debug("interface_ref: #{inspect(device.interface_ref)}")
    case Circuits.UART.open(device.interface_ref,command_port,[speed: device.baud, active: false]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        nil
      _success ->
        Logger.debug("PololuServo opened UART")
        device
    end
  end

  def output_to_ms(output, reversed, min_pw_ms, max_pw_ms) do
    # Output will arrive in range [0,1]
    if (output < 0) || (output > 1) do
      nil
    else
      case reversed do
        false ->
          min_pw_ms + output*(max_pw_ms - min_pw_ms)
        true ->
          max_pw_ms - output*(max_pw_ms - min_pw_ms)
      end
    end
  end

  def write_microseconds(device, channel, output_ms) do
    # See Pololu Maestro Servo Controller User's Guide for explanation
    message = get_message_for_channel_and_output_ms(channel, output_ms)
    Circuits.UART.write(device.interface_ref, :binary.list_to_bin(message), @default_write_timeout)
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
    Circuits.UART.write(device.interface_ref, :binary.list_to_bin(message), @default_write_timeout)
    response = read_to_list(device.interface_ref, @default_read_timeout)
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

end
