defmodule Actuator.Controller do
  use GenServer
  require Bitwise
  require Logger

  @default_port "ttyACM0"
  @default_baud 115_200

  def start_link(config) do
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    actuators_not_ready()
    begin()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        uart_ref: Sensors.Uart.Utils.get_uart_ref(),
        port: Map.get(config, :port, @default_port),
        baud: Map.get(config, :baud, @default_baud),
        actuators: config.actuators
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    open_port(state.uart_ref, state.port, state.baud)
    actuators_ready()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:actuators_ready, state) do
    Common.Utils.dispatch_cast(
      :topic_registry,
      :actuator_status,
      {:actuator_status, :ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:actuators_not_ready, state) do
    Common.Utils.dispatch_cast(
      :topic_registry,
      :actuator_status,
      {:actuator_status, :not_ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:move_actuator, actuator_name, output}, state) do
    # Logger.debug("move_actuator on #{actuator_name} to #{output}")
    actuator = get_in(state, [:actuators, actuator_name])
    channel_number = actuator.channel_number
    pwm_ms = output_to_ms(output, actuator.reversed, actuator.min_pw_ms, actuator.max_pw_ms)
    # Logger.debug("channel/number/output/ms: #{channel}/#{channel_number}/#{output}/#{inspect(pwm_ms)}")
    unless pwm_ms == nil do
      write_microseconds(state.uart_ref, channel_number, pwm_ms)
    end
    {:noreply, state}
  end

  def move_actuator(actuator_name, output) do
    # Logger.debug("move actuator for #{actuator_name}")
    GenServer.cast(__MODULE__, {:move_actuator, actuator_name, output})
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp actuators_ready() do
    GenServer.cast(__MODULE__, :actuators_ready)
  end

  defp actuators_not_ready() do
    GenServer.cast(__MODULE__, :actuators_not_ready)
  end

  defp open_port(uart_ref, port, baud) do
    Logger.debug("uart_ref: #{inspect(uart_ref)}")
    case Sensors.Uart.Utils.open_active(uart_ref,port,baud) do
      {:error, error} -> Logger.error("Error opening UART: #{inspect(error)}")
      _success -> Logger.debug("ActuatorController opened UART")
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

  defp write_microseconds(uart_ref, channel, value_ms) do
    # See Pololu Maestro Servo Controller User's Guide for explanation
    message = build_message(channel, value_ms)
    Sensors.Uart.Utils.write(uart_ref, :binary.list_to_bin(message), 10)
  end

  def build_message(channel, value_ms) do
    target = round(value_ms * 4) # 1/4us resolution
    lsb = Bitwise.&&&(target, 0x7F)
    msb = Bitwise.>>>(target, 7) |> Bitwise.&&&(0x7F)
    packet = [0x84, channel, lsb, msb]
    packet ++ [get_checksum_for_packet(packet)]
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
