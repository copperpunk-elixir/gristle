defmodule Peripherals.Uart.VnIns do
  use Bitwise
  use GenServer
  require Logger


@default_port "ttyACM0"
@default_baud 115_200
@start_byte 250
@message_length 96
@crc_start_index 94

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
        attitude_rate: %{roll: 0, pitch: 0, yaw: 0},
        gps_time: 0,
        position: %{latitude: 0, longitude: 0, altitude: 0},
        velocity: %{north: 0, east: 0, down: 0},
        magnetometer: %{x: 0, y: 0, z: 0},
        baro_pressure: 0,
        temperator: 0,
        read_timer: nil,
        start_byte_received: false,
        buffer: [],
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

  # @impl GenServer
  # def handle_info({:circuits_uart, _port, data}, state) do
  #   data_list = :binary.bin_to_list(data)
  #   IO.puts(rx)
  #   parse_buffer =
  #   if (!state.start_byte_received) do
  #     start_byte_index = find_index(data, fn x -> x==@start_byte end)
  #     if start_byte_index == nil do
  #       []
  #     else
  #       Enum.slice(data_list, start_byte_index, @message_length)
  #     end
  #   else
  #     state.buffer ++ data_list
  #   end
  #   message_group = Enum.at(parse_buffer, 1)
  #   {parse_buffer, remaining_buffer} =
  #   if (message_group == 1) do
  #     # This should be a good message
  #     {crc_calc_list, crc} = Enum.split(parse_buffer, @crc_start_index)
  #     crc_calc_value =
  #     if crc == nil do
  #       -1
  #     else
  #       Enum.reduce(crc_calc_list, 0, fn (x, crc) ->
  #         crc = (crc >>> 8) ||| (crc <<< 8)
  #         |> &&& 0xFF
  #         crc = crc ^^^ x
  #         crc = (crc &&& 0xFF)
  #         |> >>> 4
  #         |> &&& 0xFF
  #         crc = crc <<< 12
  #         |> ^^^ crc
  #         crc = crc &&& 0xFF
  #         |> <<< 5
  #         |> ^^^ crc
  #       end)
  #     end
  #     crc_b1 = crc_calc_value >>> 8
  #     crc_b2 = crc_calc_value &&& 0xFF
  #     if (crc_b1 == Enum.at(crc,0)) && (crc_b2 == Enum.at(crc,1)) do
  #       crc_calc_list
  #     end
  #   end
  #   {:noreply, state}
  # end

  # defp parse(data) do
  #   IO.puts("rxxxx");
    
  #   Enum.each(data, fn byte ->
  #     IO.puts("#{byte},")
  #   end)
  # end
end
