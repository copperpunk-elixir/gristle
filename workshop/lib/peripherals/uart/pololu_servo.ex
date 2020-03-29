defmodule Peripherals.Uart.PololuServo do
  require Bitwise
  require Logger

  @default_baud 115_200

  def open_port() do
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
    baud = @default_baud
    uart_ref = Peripherals.Uart.Utils.get_uart_ref()
    # Logger.debug("uart_ref: #{inspect(uart_ref)}")
    case Peripherals.Uart.Utils.open_passive(uart_ref,command_port,baud) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        nil
      _success ->
        Logger.debug("PololuServo opened UART")
        uart_ref
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

  def write_microseconds(uart_ref, channel, output_ms) do
    # See Pololu Maestro Servo Controller User's Guide for explanation
    message = get_message_for_channel_and_output_ms(channel, output_ms)
    Peripherals.Uart.Utils.write(uart_ref, :binary.list_to_bin(message), 10)
  end

  def get_message_for_channel_and_output_ms(channel, output_ms) do
    target = round(output_ms * 4) # 1/4us resolution
    lsb = Bitwise.&&&(target, 0x7F)
    msb = Bitwise.>>>(target, 7) |> Bitwise.&&&(0x7F)
    packet = [0x84, channel, lsb, msb]
    packet ++ [get_checksum_for_packet(packet)]
  end

  def get_output_for_channel_number(uart_ref, channel) do
    packet = [0x90, channel]
    message = packet ++ [get_checksum_for_packet(packet)]
    Peripherals.Uart.Utils.write(uart_ref, :binary.list_to_bin(message), 10)
    response = Peripherals.Uart.Utils.read(uart_ref, 100)
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

end
