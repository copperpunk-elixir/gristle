defmodule Peripherals.Uart.VnIns do
  use Bitwise
  use GenServer
  require Logger


  @default_port "ttyACM0"
  @default_baud 1_000_000
  @start_byte 250
  @payload_and_crc_length 104
  @message_length 108
  @crc_start_index 106
  @deg2rad 0.017453293
  @rad2deg 57.295779513

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
        ins: %{
          attitude: %{roll: 0,pitch: 0,yaw: 0},
          body_rate: %{roll: 0, pitch: 0, yaw: 0},
          body_accel: %{x: 0, y: 0, z: 0},
          gps_time: 0,
          position: %{latitude: 0, longitude: 0, altitude: 0},
          velocity: %{north: 0, east: 0, down: 0},
          magnetometer: %{x: 0, y: 0, z: 0},
          baro_pressure: 0,
          temperature: 0,
          gps_status: 0
        },
        read_timer: nil,
        start_byte_index: -1,
        buffer: [],
        buffer_len: 0,
        field_lengths: [8,8,8,12,16,12,24,12,12,24,20,28,2,4,8]
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
    data_list = state.buffer ++ :binary.bin_to_list(data)
    # Enum.each(data_list, fn x->
    #   Logger.info("#{x}")
    # end)
    # Logger.info("starting sbi: #{state.start_byte_index}")
   {parse_buffer, start_byte_index} =
    if (state.start_byte_index < 0) do
      start_byte_index = Enum.find_index(data_list, fn x -> x==@start_byte end)
      if start_byte_index == nil do
        {[], -1}
      else
        {Enum.slice(data_list, start_byte_index, @message_length), start_byte_index}
      end
    else
      {data_list, state.start_byte_index}
    end
    # Logger.debug("SBI: #{start_byte_index}")
    # Logger.debug("parse buffer: #{inspect(parse_buffer)}")
    message_group = Enum.at(parse_buffer, start_byte_index+1)
    crc_buffer = Enum.drop(parse_buffer, start_byte_index+1)
    # Logger.info("crc_buffer: #{inspect(crc_buffer)}")
    field_mask = calculate_field_mask(crc_buffer)
    # Logger.debug("msg group: #{message_group}")
    # Logger.debug("crc buffer (len: #{length(crc_buffer)})): #{inspect(crc_buffer)}")
    {good_message, parse_buffer,remaining_buffer, start_byte_index} =
    if (message_group == 1) do
      # Logger.debug("Message Group 1")
      # This could be a good message
      # Calculate the message length
      if (field_mask > 0) do
        payload_length = calculate_payload_length(field_mask, state.field_lengths)
        # Logger.warn("payload_length: #{payload_length}")
        {crc_calc_list, crc} = Enum.split(crc_buffer, payload_length+3);
        # {crc_calc_list, crc} = Enum.split(crc_buffer, @crc_start_index-1)
        # Logger.info("crc_calc_list len: #{length(crc_calc_list)}")
        crc_calc_value =
        if crc == [] do
          -1
        else
          crc = calculate_checksum(crc_calc_list)
        end
        # Logger.debug("crc_calc_value: #{crc_calc_value}")
        crc_b1 = crc_calc_value >>> 8
        crc_b2 = crc_calc_value &&& 0xFF
        # Logger.debug("calcb1/calcb2: #{crc_b1}/#{crc_b2}")
        # Logger.debug("crcb1/crcb2: #{Enum.at(crc,0)}/#{Enum.at(crc,1)}")
        unless (crc_calc_value == -1) do
          if (crc_b1 == Enum.at(crc,0)) && (crc_b2 == Enum.at(crc,1)) do
            # Good Checksum, drop entire message before we parse the next time
            # Logger.warn("Good checksum")
            {true, Enum.drop(crc_buffer,3),Enum.drop(crc_buffer, @message_length),-1}
          else
            # Logger.error("Bad checksum")
            # Bad checksum, which doesn't mean we lost some data
            # It could just mean that our "start byte" was just a data byte, so only
            # Drop the start byte before we parse next
            {false, [],Enum.drop(parse_buffer,1),start_byte_index+1}
          end
        else
          # Logger.warn("No checksum bytes to calculate")
          {false, [],parse_buffer,-1}
        end
      else
        {false, [], parse_buffer, -1}
      end
    else
      {false,[],parse_buffer,-1}
    end
    state =
    if (good_message) do
      state = parse_good_message(parse_buffer, field_mask, state)
    else
      state
    end
    # Logger.info("#{inspect(state)}")
    # Logger.debug("Remaining buffer: #{inspect(remaining_buffer)}")
    {:noreply, %{state | buffer: remaining_buffer, start_byte_index: start_byte_index}}
  end

  @spec calculate_field_mask(list()) :: integer()
  defp calculate_field_mask(buffer) do
    field_mask_b1 = Enum.at(buffer,1)
    field_mask_b2 = Enum.at(buffer,2)
    # Logger.warn("b1/b2: #{field_mask_b1}/#{field_mask_b2}")
    if field_mask_b1==nil do
      0
    else
      if field_mask_b2==nil do
        0
      else
        Bitwise.<<<(field_mask_b2,8)
        |> Bitwise.|||(field_mask_b1)
      end
    end
  end

  @spec calculate_payload_length(integer(), list()) :: integer()
  defp calculate_payload_length(field_mask, field_lengths) do
    Enum.reduce(0..14,0,fn(bit_index,acc) ->
      if Bitwise.&&&(field_mask,Bitwise.<<<(1,bit_index)) > 0 do
        acc + Enum.at(field_lengths,bit_index)
      else
        acc
      end
    end)
  end

  @spec calculate_checksum(list()) :: integer()
  defp calculate_checksum(buffer) do
    Enum.reduce(buffer, 0, fn (x, crc) ->
      crc = Bitwise.&&&(crc >>> 8,0xFF) ||| (crc <<< 8)
      # |> Bitwise.&&&(0xFF
      crc = crc ^^^ x
      |> Bitwise.&&&(0xFFFF)
      # crc = (crc &&& 0xFF)
      crc = crc ^^^ (Bitwise.&&&(crc, 0xFF)>>>(4))
      |> Bitwise.&&&(0xFFFF)
      # |> Bitwise.&&&(0xFF)
      crc = crc ^^^ (crc <<< 12)
      |> Bitwise.&&&(0xFFFF)
      # |> Bitwise.^^^(crc)
      # crc=crc &&& 0xFF
      crc = crc ^^^ (Bitwise.&&&(crc,0x00FF) <<< 5)
      |> Bitwise.&&&(0xFFFF)
      # |> Bitwise.<<<(5)
      # |> Bitwise.^^^(crc)
      # Logger.info("x/crc: #{x}/#{crc}")
      crc
    end)
  end

  @spec parse_good_message([char()], list(), map()) :: map()
  defp parse_good_message(buffer,field_mask, state) do
    field_mask = <<field_mask::unsigned-integer-16>>
    <<_resv_bit::1, _time_gps_pps_bit::1, _sync_in_cnt_bit::1, ins_status_bit::1, _delta_theta_bit::1, mag_pres_bit::1, _imu_bit::1, accel_bit::1,velocity_bit::1, position_bit::1, angular_rate_bit::1, _qtn_bit::1, ypr_bit::1, _time_sync_bit::1, gps_time_bit::1, _time_startup_bit::1>> = field_mask
    
  # <<_time_startup_bit::1, gps_time_bit::1, _time_sync_bit::1, ypr_bit::1, _qtn_bit::1, angular_rate_bit::1, position_bit::1, velocity_bit::1>>
    # <<accel_bit::1, _imu_bit::1, mag_pres_bit::1, _delta_theta_bit::1, ins_status_bit::1, _sync_in_cnt_bit::1, _time_gps_pps_bit::1, _resv_bit::1>>
    ins = state.ins
    {gps_time, buffer} =
    if (gps_time_bit == 1) do
      {gps_time_uint64, buffer} = Enum.split(buffer, 8)
      {list_to_int(gps_time_uint64,8)/1000000000, buffer}
    else
      {ins.gps_time, buffer}
    end

    {attitude, buffer} = if(ypr_bit == 1) do
      {yaw_deg_uint32, buffer} = Enum.split(buffer, 4)
      {pitch_deg_uint32, buffer} = Enum.split(buffer, 4)
      {roll_deg_uint32, buffer} = Enum.split(buffer, 4)
      yaw_deg = list_to_int(yaw_deg_uint32, 4) |> Common.Utils.Math.fp_from_uint(32)
      pitch_deg = list_to_int(pitch_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      roll_deg = list_to_int(roll_deg_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      {%{
        roll: roll_deg*@deg2rad,
        pitch: pitch_deg*@deg2rad,
        yaw: yaw_deg*@deg2rad
       }, buffer}
    else
      {ins.attitude, buffer}
    end
    
    # Logger.warn("parse buffer: #{inspect(buffer)}")
    {body_rate, buffer} = if(angular_rate_bit==1) do
      {roll_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
      {pitch_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
      {yaw_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
      roll_rate_rad = list_to_int(roll_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      pitch_rate_rad = list_to_int(pitch_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      yaw_rate_rad = list_to_int(yaw_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      {%{
            roll: roll_rate_rad,
            pitch: pitch_rate_rad,
            yaw: yaw_rate_rad
      }, buffer}
    else
      {ins.body_rate, buffer}
    end

    {position, buffer} = if(position_bit == 1) do
      {latitude_deg_uint64, buffer} = Enum.split(buffer, 8)
      {longitude_deg_uint64, buffer} = Enum.split(buffer, 8)
      {altitude_m_uint64, buffer} = Enum.split(buffer, 8)
      latitude_deg = list_to_int(latitude_deg_uint64,8) |> Common.Utils.Math.fp_from_uint(64)
      longitude_deg = list_to_int(longitude_deg_uint64,8) |> Common.Utils.Math.fp_from_uint(64)
      altitude_m = list_to_int(altitude_m_uint64,8) |> Common.Utils.Math.fp_from_uint(64)
      {%{
          latitude: latitude_deg*@deg2rad,
          longitude: longitude_deg*@deg2rad,
          altitude: altitude_m
       }, buffer}
    else
      {ins.position, buffer}
    end

    {velocity, buffer} = if(velocity_bit == 1) do
      {vel_north_mps_uint32, buffer} = Enum.split(buffer, 4)
      {vel_east_mps_uint32, buffer} = Enum.split(buffer, 4)
      {vel_down_mps_uint32, buffer} = Enum.split(buffer, 4)
      vel_north_mps = list_to_int(vel_north_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      vel_east_mps = list_to_int(vel_east_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      vel_down_mps = list_to_int(vel_down_mps_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      {%{
        north: vel_north_mps,
        east: vel_east_mps,
        down: vel_down_mps
      }, buffer}
    else
      {ins.velocity, buffer}
    end

    {body_accel, buffer} = if(accel_bit == 1) do
      {accel_x_mpss_uint32, buffer} = Enum.split(buffer, 4)
      {accel_y_mpss_uint32, buffer} = Enum.split(buffer, 4)
      {accel_z_mpss_uint32, buffer} = Enum.split(buffer, 4)
      accel_x_mpss = list_to_int(accel_x_mpss_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      accel_y_mpss = list_to_int(accel_y_mpss_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      accel_z_mpss = list_to_int(accel_z_mpss_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      {%{
          x: accel_x_mpss,
          y: accel_y_mpss,
          z: accel_z_mpss
       }, buffer}
    else
      {ins.accel_body, buffer}
    end

    {magnetometer, baro_pressure, temperature, buffer} = if(mag_pres_bit == 1) do
      {mag_x_gauss_uint32, buffer} = Enum.split(buffer, 4)
      {mag_y_gauss_uint32, buffer} = Enum.split(buffer, 4)
      {mag_z_gauss_uint32, buffer} = Enum.split(buffer, 4)
      {temp_c_uint32, buffer} = Enum.split(buffer, 4)
      {pressure_kpa_uint32, buffer} = Enum.split(buffer, 4)
      mag_x_gauss = list_to_int(mag_x_gauss_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      mag_y_gauss = list_to_int(mag_y_gauss_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      mag_z_gauss = list_to_int(mag_z_gauss_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      temp_c = list_to_int(temp_c_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      pressure_kpa = list_to_int(pressure_kpa_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      {%{
          x: mag_x_gauss,
          y: mag_y_gauss,
          z: mag_z_gauss
       },
       pressure_kpa,
       temp_c,
       buffer
      }
    else
      {ins.magnetometer, ins.baro_pressure, ins.temperature, buffer}
    end

    {gps_status, buffer} = if (ins_status_bit == 1) do
      {ins_status, buffer} = Enum.split(buffer, 2)
      <<_res::1, ins_error::4, gnss_fix::1, mode::2>> = <<Enum.at(ins_status,0)>>
      <<_rest::6, gnss_compass::1, gnss_headings_ins::1>> = <<Enum.at(ins_status,1)>>
      {mode, buffer}
    else
      {ins.gps_status, buffer}
    end

    # Logger.info("yaw: #{list_to_int(yaw_deg_uint32,4)}")
    # Logger.info("roll_rate_rad: #{list_to_int(roll_rate_rad_uint32,4)}")
    Logger.info("time: #{gps_time}")
    Logger.info("rpy: #{eftb(attitude.roll*@rad2deg,2)}/#{eftb(attitude.pitch*@rad2deg,2)}/#{eftb(attitude.yaw*@rad2deg,2)}")
    Logger.info("lat: #{eftb(position.latitude*@rad2deg,6)}")
    Logger.info("gps_status: #{gps_status}")
    # new_state = %{
    #   gps_time: gps_time,
    #   attitude: %{
    #     roll: roll_deg*@deg2rad,
    #     pitch: pitch_deg*@deg2rad,
    #     yaw: yaw_deg*@deg2rad
    #   }, 
    #   attitude_rate: %{
    #     roll: roll_rate_rad,
    #     pitch: pitch_rate_rad,
    #     yaw: yaw_rate_rad
    #   },
    #   position: %{
    #     latitude: latitude_deg*@deg2rad,
    #     longitude: longitude_deg*@deg2rad,
    #     altitude: altitude_m
    #   },
    #   velocity: %{
    #     north: vel_north_mps,
    #     east: vel_east_mps,
    #     down: vel_down_mps
    #   },
    #   # magnetometer: %{
    #   #   x: mag_x_gauss,
    #   #   y: mag_y_gauss,
    #   #   z: mag_z_gauss
    #   # },
    #   # baro_pressure: pressure_kpa,
    #   # temperator: temp_c,
    #   ins_status: mode
    # }
    ins = %{gps_time: gps_time, attitude: attitude, body_rate: body_rate, position: position, velocity: velocity, magnetometer: magnetometer, baro_pressure: baro_pressure, temperature: temperature, gps_status: gps_status}
    Map.put(state, :ins, ins)
  end

  def list_to_int(x_list,bytes) do
    Enum.reduce(Enum.with_index(x_list),0,fn ({value,index},acc) ->
      acc + (value<<<(8*index))
    end)
  end

  def eftb(num, dec) do
    Common.Utils.eftb(num,dec)
  end
end
