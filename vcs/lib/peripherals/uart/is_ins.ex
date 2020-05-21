defmodule Peripherals.Uart.IsIns do
  use Bitwise
  use GenServer
  require Logger


@default_port "ttyACM0"
@default_baud 1_000_000

  def start_link(config) do
    Logger.debug("Start VectorNav INS GenServer")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        uart_ref: Peripherals.Uart.Utils.get_uart_ref(),
        port: Map.get(config, :port, @default_port),
        baud: Map.get(config, :baud, @default_baud),
        attitude: %{roll: 0,pitch: 0,yaw: 0},
        body_rate: %{roll: 0, pitch: 0, yaw: 0},
        gps_time: 0,
        position: %{latitude: 0, longitude: 0, altitude: 0},
        position_ned: %{north: 0, east: 0, down: 0},
        velocity: %{north: 0, east: 0, down: 0},
        read_timer: nil,
        start_byte_received: false,
        buffer: "",
        buffer_len: 0
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Logger.debug("VN INS begin with process: #{inspect(self())}")
    Peripherals.Uart.Utils.open_active(state.uart_ref, state.port, state.baud)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    IO.puts("rx: #{inspect(data)}")
    buffer = state.buffer <> data
    parse_buffer = String.split(buffer, ["$","*", "\r\n"])
    IO.puts("parse_buffer: #{inspect(parse_buffer)}")
    payload = Enum.at(parse_buffer,1)
    checksum = Enum.at(parse_buffer,2)
    IO.puts("payload: #{payload}")
    IO.puts("checksum: #{inspect(checksum)}")
    remaining_buffer = if (payload == nil) do
      parse_buffer
    else
      if checksum == nil do
        payload
      else
        Enum.at(parse_buffer,3)
      end
    end
    IO.puts("Remaining: #{inspect(remaining_buffer)}")
    IO.puts("is string? #{inspect(String.valid?(checksum))}")
    data_map = unless ((payload==nil) || (checksum == nil)) do
      {checksum_dec, _rem} =
        case Integer.parse(checksum, 16) do
          {num, remainder} -> {num, remainder}
          error ->
            IO.puts("bad checksum decode: #{inspect(error)}")
            {nil, nil}
        end
      IO.puts("checksum dec: #{checksum_dec}")
      unless checksum_dec == nil do
        checksum_calc = calculate_checksum(payload)
        if checksum_calc == checksum_dec do
          parse_payload(payload)
        else
          IO.puts("Bad checksum: %inspect(checksum_calc)")
          %{}
        end
      else
        %{}
      end
    end
    IO.puts("roll: #{state.attitude.roll * 57.3}")
    state = Map.put(state,:buffer, remaining_buffer)
    {:noreply, Map.merge(state, data_map)}
  end

  defp parse_payload(payload) do
    payload_list = String.split(payload, ",")
    case Enum.at(payload_list, 0) do
      "PIMU" -> parse_pimu(payload_list)
      "PINS1" -> parse_pins1(payload_list)
      unknown ->
        IO.puts("Unknown message ID: #{inspect(unknown)}")
        %{}
    end
  end

  defp calculate_checksum(payload) do
    Enum.reduce(String.to_charlist(payload), 0, fn (x,acc) ->
      Bitwise.bxor(acc, x)
    end)
  end

  defp parse_pimu(payload) do
    %{
      attitude: %{roll: String.to_float(Enum.at(payload, 3)), pitch: String.to_float(Enum.at(payload, 2)), yaw: String.to_float(Enum.at(payload, 4))},
      body_rate: %{roll: String.to_float(Enum.at(payload, 9)), pitch: String.to_float(Enum.at(payload, 8)), yaw: String.to_float(Enum.at(payload, 10))}
    }
  end

  defp parse_pins1(payload) do
    Logger.warn("parse_pins1 not defined. #{inspect(payload)}")
  end
end
