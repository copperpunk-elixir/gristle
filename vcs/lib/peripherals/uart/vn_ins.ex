defmodule Peripherals.Uart.VnIns do
  use Bitwise
  use GenServer
  require Logger


  @default_port "ttyACM0"
  @default_baud 1_000_000
  @start_byte 250
  @message_length 96
  @crc_start_index 94
  @deg2rad 0.017453293

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
        ins_status: 0,
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

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    data_list = :binary.bin_to_list(data)

    Logger.debug("rx: #{inspect(data_list)}")
    parse_buffer =
    if (!state.start_byte_received) do
      start_byte_index = Enum.find_index(data, fn x -> x==@start_byte end)
      if start_byte_index == nil do
        []
      else
        Enum.slice(data_list, start_byte_index, @message_length)
      end
    else
      state.buffer ++ data_list
    end
    message_group = Enum.at(parse_buffer, 1)
    {parse_buffer, remaining_buffer} =
      good_message =
    if (message_group == 1) do
      Logger.debug("Good message")
      # This should be a good message
      {crc_calc_list, crc} = Enum.split(parse_buffer, @crc_start_index)
      crc_calc_value =
      if crc == nil do
        -1
      else
        Enum.reduce(crc_calc_list, 0, fn (x, crc) ->
          crc = (crc >>> 8) ||| (crc <<< 8)
          |> Bitwise.&&&(0xFF)
          crc = crc ^^^ x
          crc = (crc &&& 0xFF)
          |> Bitwise.>>>(4)
          |> Bitwise.&&&(0xFF)
          crc = crc <<< 12
          |> Bitwise.^^^(crc)
          crc &&& 0xFF
          |> Bitwise.<<<(5)
          |> Bitwise.^^^(crc)
        end)
      end
      Logger.debug("crc_calc_value: #{crc_calc_value}")
      crc_b1 = crc_calc_value >>> 8
      crc_b2 = crc_calc_value &&& 0xFF
      if (crc_b1 == Enum.at(crc,0)) && (crc_b2 == Enum.at(crc,1)) do
        true
      else
        false
      end
    end
    state = if (good_message) do
      parse_good_message(parse_buffer, state)
    else
      state
    end
    Logger.debug("Remaining buffer: #{inspect(remaining_buffer)}")
    {:noreply, %{state | buffer: remaining_buffer}}
  end

  @spec parse_good_message([char()], map()) :: map()
  defp parse_good_message(buffer, state) do
    {gps_time_uint64, buffer} = Enum.split(buffer, 8)
    {yaw_deg_uint32, buffer} = Enum.split(buffer, 4)
    {pitch_deg_uint32, buffer} = Enum.split(buffer, 4)
    {roll_deg_uint32, buffer} = Enum.split(buffer, 4)
    {roll_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
    {pitch_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
    {yaw_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
    {latitude_deg_uint64, buffer} = Enum.split(buffer, 8)
    {longitude_deg_uint64, buffer} = Enum.split(buffer, 8)
    {altitude_m_uint64, buffer} = Enum.split(buffer, 8)
    {vel_north_mps_uint32, buffer} = Enum.split(buffer, 4)
    {vel_east_mps_uint32, buffer} = Enum.split(buffer, 4)
    {vel_down_mps_uint32, buffer} = Enum.split(buffer, 4)
    {mag_x_gauss_uint32, buffer} = Enum.split(buffer, 4)
    {mag_y_gauss_uint32, buffer} = Enum.split(buffer, 4)
    {mag_z_gauss_uint32, buffer} = Enum.split(buffer, 4)
    {temp_c_uint32, buffer} = Enum.split(buffer, 4)
    {pressure_kpa_uint32, buffer} = Enum.split(buffer, 4)
    <<_rest::6, gnss_compass::1, gnss_headings_ins::1, _res::1, gnss_fix::1, mode::2>> = Enum.split(buffer, 2)
    gps_time = Common.Utils.Math.twos_comp_64(gps_time_uint64) |> Common.Utils.Math.fp_from_uint(64)
    yaw_deg = Common.Utils.Math.twos_comp_32(yaw_deg_uint32) |> Common.Utils.Math.fp_from_uint(32)
    pitch_deg = Common.Utils.Math.twos_comp_32(pitch_deg_uint32) |> Common.Utils.Math.fp_from_uint(32)
    roll_deg = Common.Utils.Math.twos_comp_32(roll_deg_uint32) |> Common.Utils.Math.fp_from_uint(32)
    roll_rate_rad = Common.Utils.Math.twos_comp_32(roll_rate_rad_uint32) |> Common.Utils.Math.fp_from_uint(32)
    pitch_rate_rad = Common.Utils.Math.twos_comp_32(pitch_rate_rad_uint32) |> Common.Utils.Math.fp_from_uint(32)
    yaw_rate_rad = Common.Utils.Math.twos_comp_32(yaw_rate_rad_uint32) |> Common.Utils.Math.fp_from_uint(32)
    latitude_deg = Common.Utils.Math.twos_comp_64(latitude_deg_uint64) |> Common.Utils.Math.fp_from_uint(64)
    longitude_deg = Common.Utils.Math.twos_comp_64(longitude_deg_uint64) |> Common.Utils.Math.fp_from_uint(64)
    altitude_m = Common.Utils.Math.twos_comp_64(altitude_m_uint64) |> Common.Utils.Math.fp_from_uint(64)
    vel_north_mps = Common.Utils.Math.twos_comp_32(vel_north_mps_uint32) |> Common.Utils.Math.fp_from_uint(32)
    vel_east_mps = Common.Utils.Math.twos_comp_32(vel_east_mps_uint32) |> Common.Utils.Math.fp_from_uint(32)
    vel_down_mps = Common.Utils.Math.twos_comp_32(vel_down_mps_uint32) |> Common.Utils.Math.fp_from_uint(32)
    mag_x_gauss = Common.Utils.Math.twos_comp_32(mag_x_gauss_uint32) |> Common.Utils.Math.fp_from_uint(32)
    mag_y_gauss = Common.Utils.Math.twos_comp_32(mag_y_gauss_uint32) |> Common.Utils.Math.fp_from_uint(32)
    mag_z_gauss = Common.Utils.Math.twos_comp_32(mag_z_gauss_uint32) |> Common.Utils.Math.fp_from_uint(32)
    temp_c = Common.Utils.Math.twos_comp_32(temp_c_uint32) |> Common.Utils.Math.fp_from_uint(32)
    pressure_kpa = Common.Utils.Math.twos_comp_32(pressure_kpa_uint32) |> Common.Utils.Math.fp_from_uint(32)

    new_state = %{
      attitude: %{
        roll: roll_deg*@deg2rad,
        pitch: pitch_deg*@deg2rad,
        yaw: yaw_deg*@deg2rad
      },
      attitude_rate: %{
        roll: roll_rate_rad,
        pitch: pitch_rate_rad,
        yaw: yaw_rate_rad
      },
      position: %{
        latitude: latitude_deg*@deg2rad,
        longitude: longitude_deg*@deg2rad,
        altitude: altitude_m
      },
      velocity: %{
        north: vel_north_mps,
        east: vel_east_mps,
        down: vel_down_mps
      },
      magnetometer: %{
        x: mag_x_gauss,
        y: mag_y_gauss,
        z: mag_z_gauss
      },
      baro_pressure: pressure_kpa,
      temperator: temp_c,
      ins_status: mode
    }
    Map.merge(state, new_state)
  end
end
