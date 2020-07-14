defmodule Peripherals.Uart.VnIns do
  use Bitwise
  use GenServer
  require Logger


  # @default_port "ttyACM2"
  @default_device_description "SFE SAMD21"
  @default_baud 1_000_000
  @start_byte 250
  # @payload_and_crc_length 104
  # @message_length 108
  # @crc_start_index 106
  @deg2rad 0.017453293
  @rad2deg 57.295779513

  def start_link(config) do
    Logger.debug("Start VectorNav INS GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        device_description: Map.get(config, :device_description, @default_device_description),
        baud: Map.get(config, :baud, @default_baud),
        ins: %{
          attitude: %{roll: 0,pitch: 0,yaw: 0},
          bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0},
          body_accel: %{x: 0, y: 0, z: 0},
          gps_time: 0,
          position: %{latitude: 0, longitude: 0, altitude: 0},
          velocity: %{north: 0, east: 0, down: 0},
          magnetometer: %{x: 0, y: 0, z: 0},
          baro_pressure: 0,
          temperature: 0,
          gps_status: 0
        },
        start_byte_found: false,
        remaining_buffer: [],
        field_lengths_binary_1: [8,8,8,12,16,12,24,12,12,24,20,28,2,4,8],
        new_ins_data_to_publish: false,
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Logger.debug("VN INS begin with process: #{inspect(self())}")
    ins_port = Common.Utils.get_uart_devices_containing_string(state.device_description)
    case Circuits.UART.open(state.uart_ref, ins_port,[speed: state.baud, active: true]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{ins_port} is unavailable"
      _success ->
        Logger.debug("VN INS opened #{ins_port}")
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    data_list = state.remaining_buffer ++ :binary.bin_to_list(data)
    # Enum.each(data_list, fn x->
    #   Logger.info("#{x}")
    # end)
    state = parse_data_buffer(data_list, state)
    ins = state.ins
    # Logger.info("time: #{ins.gps_time}")
    # Logger.info("lat/lon/alt: #{eftb(ins.position.latitude*@rad2deg,6)}/#{eftb(ins.position.longitude*@rad2deg,6)}/#{eftb(ins.position.altitude,1)}")
    # Logger.info("gps_status: #{ins.gps_status}")

    state = if (state.new_ins_data_to_publish) do

      # Logger.info("rpy: #{eftb(ins.attitude.roll*@rad2deg,2)}/#{eftb(ins.attitude.pitch*@rad2deg,2)}/#{eftb(ins.attitude.yaw*@rad2deg,2)}")
      publish_ins_data(ins)
      %{state | new_ins_data_to_publish: false}
    else
      state
    end
    {:noreply, state}
  end

  defp publish_ins_data(ins_data) do
    attitude_bodyrate_value_map = %{attitude: ins_data.attitude, bodyrate: ins_data.bodyrate}
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :attitude_bodyrate}, attitude_bodyrate_value_map}, {:pv_calculated, :attitude_bodyrate}, self())
    position_velocity_value_map = %{position: ins_data.position, velocity: ins_data.velocity}
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :position_velocity}, position_velocity_value_map}, {:pv_calculated, :position_velocity}, self())
  end

  @spec parse_data_buffer(list(), map()) :: map()
  defp parse_data_buffer(entire_buffer, state) do
    {valid_buffer, start_byte_found} =
    if (!state.start_byte_found) do
      # A start byte has not been found yet. Search for it
      start_byte_index = Enum.find_index(entire_buffer, fn x -> x==@start_byte end)
      if start_byte_index == nil do
        # No start byte in the entire buffer, throw it all away
        {[], false}
      else
        # The buffer contains a start byte
        # Throw out everything before the start byte
        {_removed, valid_buffer} = Enum.split(entire_buffer,start_byte_index)
        {valid_buffer, true}
      end
    else
      # There is a valid start byte leftover from the last read
      {entire_buffer, true}
    end
    if start_byte_found do
      # The valid buffer should contain only the bytes after (and including) the start byte
      message_group_index = 1
      message_group = Enum.at(valid_buffer, message_group_index)
      # The crc is calculated on everything after the start byte
      crc_calculation_buffer_and_remaining = Enum.drop(valid_buffer, message_group_index)
      field_mask = calculate_field_mask(crc_calculation_buffer_and_remaining)
      {state, parse_again} =
      if (message_group == 1) do
        # This could be a good message
        # Calculate the message length
        if (field_mask > 0) do
          payload_length = calculate_payload_length(field_mask, state.field_lengths_binary_1)
          # CRC calculation includes the message_group byte and the two field_mask bytes
          # The CRC is contained in the two bytes immediately following the payload
          crc_calculation_num_bytes = payload_length + 3
          {crc_calculation_buffer, crc_and_remaining_buffer} = Enum.split(crc_calculation_buffer_and_remaining, crc_calculation_num_bytes);
          unless Enum.empty?(crc_and_remaining_buffer) do
            crc_calc_value = calculate_checksum(crc_calculation_buffer)
            crc_b1 = crc_calc_value >>> 8
            crc_b2 = crc_calc_value &&& 0xFF
            if (crc_b1 == Enum.at(crc_and_remaining_buffer,0)) && (crc_b2 == Enum.at(crc_and_remaining_buffer,1)) do
              # Good Checksum, drop entire message before we parse the next time
              # The payload does not include the message_group byte or the field_mask bytes
              # We can leave the CRC bytes attached to the end of the payload buffer, because we know the length
              # The remaining_buffer is everything after the CRC bytes
              payload_buffer = Enum.drop(crc_calculation_buffer,3)
              remaining_buffer = Enum.drop(payload_buffer, payload_length+2)
              ins = parse_good_message(payload_buffer, field_mask, state.ins)
              state = %{state |
                        remaining_buffer: remaining_buffer,
                        start_byte_found: false,
                        ins: ins,
                        new_ins_data_to_publish: true}
              {state, true}
            else
              # Bad checksum, which doesn't mean we lost some data
              # It could just mean that our "start byte" was just a data byte, so only
              # Drop the start byte before we parse next
              remaining_buffer = Enum.drop(valid_buffer,1)
              state = %{state |
                        remaining_buffer: remaining_buffer,
                        start_byte_found: false}
              {state, true}
            end
          else
            # We have not received enough data to parse a complete message
            # The next loop should try again with the same start_byte
            state = %{state |
                      remaining_buffer: valid_buffer,
                      start_byte_found: true}
            {state, false}
          end
        else
          state = %{state |
                    remaining_buffer: [],
                    start_byte_found: false}
          {state, false}
        end
      else
        state = %{state |
                  remaining_buffer: [],
                  start_byte_found: false}
        {state, false}
      end
      if (parse_again) do
        parse_data_buffer(state.remaining_buffer, state)
      else
        state
      end
    else
      %{state | start_byte_found: false}
    end
  end

  @spec calculate_field_mask(list()) :: integer()
  defp calculate_field_mask(buffer) do
    field_mask_b1 = Enum.at(buffer,1)
    field_mask_b2 = Enum.at(buffer,2)
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
  defp parse_good_message(buffer,field_mask, ins) do
    field_mask = <<field_mask::unsigned-integer-16>>
    <<_resv_bit::1, _time_gps_pps_bit::1, _sync_in_cnt_bit::1, ins_status_bit::1, _delta_theta_bit::1, mag_pres_bit::1, _imu_bit::1, accel_bit::1,velocity_bit::1, position_bit::1, angular_rate_bit::1, _qtn_bit::1, ypr_bit::1, _time_sync_bit::1, gps_time_bit::1, _time_startup_bit::1>> = field_mask

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

    {bodyrate, buffer} = if(angular_rate_bit==1) do
      {roll_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
      {pitch_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
      {yaw_rate_rad_uint32, buffer} = Enum.split(buffer, 4)
      roll_rate_rad = list_to_int(roll_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      pitch_rate_rad = list_to_int(pitch_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      yaw_rate_rad = list_to_int(yaw_rate_rad_uint32,4) |> Common.Utils.Math.fp_from_uint(32)
      {%{
            rollrate: roll_rate_rad,
            pitchrate: pitch_rate_rad,
            yawrate: yaw_rate_rad
      }, buffer}
    else
      {ins.bodyrate, buffer}
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

    {gps_status, _buffer} = if (ins_status_bit == 1) do
      {ins_status, buffer} = Enum.split(buffer, 2)
      <<_res1_DNU::1, _ins_error::4, _gnss_fix::1, mode::2>> = <<Enum.at(ins_status,0)>>
      <<_res2_DNU::6, _gnss_compass::1, _gnss_headings_ins::1>> = <<Enum.at(ins_status,1)>>
      {mode, buffer}
    else
      {ins.gps_status, buffer}
    end

    %{gps_time: gps_time, attitude: attitude, bodyrate: bodyrate, body_accel: body_accel, position: position, velocity: velocity, magnetometer: magnetometer, baro_pressure: baro_pressure, temperature: temperature, gps_status: gps_status}
  end

  def list_to_int(x_list, bytes) do
    Enum.reduce(0..bytes-1, 0, fn(index,acc) ->
      acc + (Enum.at(x_list,index)<<<(8*index))
    end)
  end

  def eftb(num, dec) do
    Common.Utils.eftb(num,dec)
  end
end
