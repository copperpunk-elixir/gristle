defmodule Bno080 do
  @moduledoc """
  """
  use Bitwise
  use GenServer
  require Logger

  @default_sleep 200
  @flag_byte 0x7e
  @control_escape 0x7d

  # @channel_command 0
  # @channel_executable 1
  @channel_control 2
  @channel_reports 3

  @shtp_report_command_response 0xF1
  @shtp_report_product_id_request 0xF9
  @shtp_report_base_delay 0xFB
  @shtp_report_set_feature_command 0xFD

  @sensor_reportid_accelerometer 0x01
  # @sensor_reportid_gyroscope 0x02
  @sensor_reportid_rotation_vector 0x05
  @sensor_reportid_game_rotation_vector 0x08
  @sensor_reportid_arvr_game_rotation_vector 0x29

  @default_port "ttyAMA0"
  @default_baud 3_000_000

  def start_link(config) do
    Logger.debug("Start BNO080 GenServer")
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    imu_not_ready()
    begin()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        uart_ref: Bno080.Utils.get_uart_ref(),
        reset_ref: Bno080.Utils.get_gpio_ref_output(config.interface.reset_pin),
        wake_ref: Bno080.Utils.get_gpio_ref_output(config.interface.wake_pin),
        port: Map.get(config, :port, @default_port),
        baud: Map.get(config, :baud, @default_baud),
        attitude_callback: Map.get(config, :attitude_callback, nil),
        update_interval_ms: config.interface.update_interval_ms,
        sequence_numbers: {0,0,0},
        shtp_header: {0,0,0,0},
        attitude: %{quat: %{x: 0,y: 0,z: 0,w: 0}, euler: %{roll: 0,pitch: 0,yaw: 0}, euler_rate: %{roll: 0, pitch: 0, yaw: 0}, dt: 0, status: 0, delay_us: 0, time_prev_us: nil, available: false},
        read_timer: nil,
        flag_byte_received: false,
        last_packet: [],
        imu_ready: false
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Logger.debug("BNO begin with process: #{inspect(self())}")
    open_port(state.uart_ref, state.port, state.baud)
    hard_reset(state.wake_ref, state.reset_ref)
    state = check_communication(state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:imu_ready, state) do
    Common.Utils.Comms.dispatch_cast(
      :topic_registry,
      :imu_status,
      {:imu_status, :ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:imu_not_ready, state) do
    Logger.debug("Received call: imu_not_ready")
    Common.Utils.Comms.dispatch_cast(
      :topic_registry,
      :imu_status,
      {:imu_status, :not_ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    state = parse_input_report(state, :binary.bin_to_list(data))
    #TODO put the following in its own function
    state = if(state.attitude.available) do
      GenServer.cast(state.attitude_callback, :euler_eulerrate_dt, {:euler_eulerrate_dt, state.attitude.euler, state.attitude.euler_rate, state.attitude.dt})
      %{state | attitude: %{state.attitude | available: false}}
    else
      state
    end
    {:noreply, state}
  end

  def begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp hard_reset(wake_ref, reset_ref) do
    Bno080.Utils.gpio_write(wake_ref, 1)
    Process.sleep(100)
    Bno080.Utils.write(reset_ref, 0)
    Process.sleep(1000)
    Bno080.Utils.write(reset_ref, 1)
    Process.sleep(@default_sleep)
    Bno080.Utils.write(wake_ref,0)
  end

  defp open_port(uart_ref, port, baud) do
    Logger.debug("uart_ref: #{inspect(uart_ref)}")
    Logger.debug(Bno080.Utils.open_active(uart_ref,port,baud))
  end

  # defp soft_reset(state) do
  #   state = send_packet_and_return_state(state, @channel_executable,[1])
  #   Process.sleep(@default_sleep)
  #   # flush data
  #   flush_data(state)
  #   Process.sleep(@default_sleep)
  #   state
  # end

  def check_communication(state) do
    packet = [@shtp_report_product_id_request, 0]
    state = send_packet_and_return_state(state, @channel_control, packet)
    Logger.debug("Check comms complete")
    state
  end

  def start_measurements(state) do
    enable_feature(state, :game_rotation_vector, state.update_interval_ms)
  end

  defp imu_ready() do
    GenServer.cast(__MODULE__, :imu_ready)
  end

  defp imu_not_ready() do
    GenServer.cast(__MODULE__, :imu_not_ready)
  end

  defp send_packet_and_return_state(state, channel, byte_list) do
    Logger.debug("Send packet to ch #{channel}: #{inspect(byte_list)}")
    packet_length = length(byte_list)+4
    seq_nums = state.sequence_numbers
    seq = elem(seq_nums,channel)
    header = [packet_length &&& 0xFF, packet_length >>> 8, channel,seq]
    data_packet = header ++ byte_list
    # Logger.debug("Byte packet of len #{packet_length}: #{inspect(data_packet)}")
    total_packet = [@flag_byte,1] ++ check_packet_for_escape_chars(data_packet) ++ [@flag_byte]
    # Logger.debug("Byte packet after adding/checking escape chars: #{inspect(:binary.list_to_bin(total_packet))}")
    Enum.each(total_packet, fn x -> Bno080.Utils.write(state.uart_ref,<<x>>,10) end)
    # Peripherals.I2c.Utils.write_packet(state.bus_ref, state.address, total_packet)
    seq_nums = put_elem(seq_nums, channel, seq+1)
    %{state | sequence_numbers: seq_nums}
  end

  defp check_packet_for_escape_chars(packet) do
    Enum.reduce(packet,[], fn (value, acc) ->
      case value do
        @flag_byte ->
          acc ++ [@control_escape,0x5E]
        @control_escape ->
          acc ++ [@control_escape,0x5D]
        x ->
          acc ++ [x]
      end
    end )
  end

  defp enable_feature(state, feature, update_interval_ms) do
    {report_id, specific_config} =
      case feature do
        :accelerometer -> {@sensor_reportid_accelerometer, 0}
        :rotation_vector -> {@sensor_reportid_rotation_vector, 0}
        :game_rotation_vector -> {@sensor_reportid_game_rotation_vector, 0}
        :arvr_game_rotation_vector -> {@sensor_reportid_arvr_game_rotation_vector, 0}
        _ -> {0,0}
    end
    if (report_id > 0) and (update_interval_ms > 0) do
      # millis_between_reports = ceil(1000/freq)
      set_feature_command_and_return_state(state, report_id, update_interval_ms, specific_config)
    end
  end

  def set_feature_command_and_return_state(state, report_id, update_interval_ms, specific_config) do
    Logger.debug("update interval: #{update_interval_ms}")
    micros_between_reports = update_interval_ms * 1000
    packet = [
      @shtp_report_set_feature_command,
      report_id,
      0,
      0,
      0,
      (micros_between_reports) &&& 0xFF,
      (micros_between_reports >>> 8) &&& 0xFF,
      (micros_between_reports >>> 16) &&& 0xFF,
      (micros_between_reports >>> 24) &&& 0xFF,
      0,
      0,
      0,
      0,
      (specific_config) &&& 0xFF,
      (specific_config >>> 8) &&& 0xFF,
      (specific_config >>> 16) &&& 0xFF,
      (specific_config >>> 24) &&& 0xFF
    ]
    Logger.debug("packet: #{inspect(packet)}")
    send_packet_and_return_state(state, @channel_control, packet)
  end

  defp parse_input_report(state, data_list) do
    # Logger.debug("data: #{inspect(data_list)}")
    # First find out if we have a valid packet by checking for the start and end bytes
    {state, data_list, valid_packet} = check_for_valid_packet(state, data_list)
    if valid_packet do
      # Logger.debug("Valid packet")
      # Extract the header and data from the packet
      {header, data} = get_header_and_data_from_packet(data_list)
      data_length = length(data) - 1
      header = List.to_tuple(header)
      data = List.to_tuple(data)
      # Logger.debug("header/data: #{inspect(header)}/#{inspect(data)}")
      # data_length = get_data_length_from_sensor_header(state) - 4 # remove the header bytes from the count
      data_channel = elem(header,2)
      report_type = elem(data,0)
      cond do
        data_channel == @channel_reports && report_type == @shtp_report_base_delay && data_length>14 ->
          #INPUT REPORT
          # Logger.debug("parse input data of length #{data_length}: #{inspect(data)}")
          data_time_us = :erlang.monotonic_time(:microsecond)
          # Logger.debug("Received from #{inspect(port)} at #{inspect(ct/1000)}: #{inspect(data)}")
          report_id = elem(data,5)
          delay_us = (elem(data,4) <<< 24) ||| (elem(data,3) <<< 16) ||| (elem(data,2) <<< 8) ||| elem(data,1)
          status = elem(data,7) &&& 0x03
          data1 = (elem(data,10) <<< 8) ||| elem(data,9)
          data2 = (elem(data,12) <<< 8) ||| elem(data,11)
          data3 = (elem(data,14) <<< 8) ||| elem(data,13)
          data4  =
          if (data_length > 16) do
            (elem(data,16) <<< 8) ||| elem(data,15)
          else
            0
          end
          data5 =
          if (data_length > 18) do
            (elem(data,18) <<< 8) ||| elem(data,17)
          else
            0
          end

          data_to_process = [data1, data2, data3, data4, data5]
          # Logger.debug("#{report_id}/#{delay}/#{data5}")
          process_data(state, data_to_process, report_id, status, delay_us, data_time_us)

        data_channel == @channel_control && report_type == @shtp_report_command_response ->
          Logger.debug("Ready to start!")
          start_measurements(state)
          imu_ready()
          state
        true ->
          state
      end
    else
      state
    end
  end


  defp check_for_valid_packet(state, data_list) do
    data_list =
    if hd(data_list)!=@flag_byte do
      # Logger.debug("No start byte")
      if state.flag_byte_received do
        # Logger.debug("But it already exists")
        state.last_packet ++ data_list
      else
        # Logger.debug("toss this message")
        []
      end
    else
      # Logger.debug("Start byte rx")
      data_list
    end

    data_length = length(data_list)
    # Logger.debug("data to check: #{inspect(data_list)}")
    {state,valid_packet} =
    if (data_length > 5) do
      data = List.to_tuple(data_list)
      # Logger.debug("tuple: #{inspect(data)}")
      if (elem(data, data_length-1) == @flag_byte) do
        # Logger.debug("Good start and end byte")
        {%{state | last_packet: [], flag_byte_received: false}, true}
      else
        # Logger.debug("Bad end byte, hold onto packet") #TODO there should be a max amount of packets we hold on to
        {%{state | last_packet: data_list, flag_byte_received: true}, false}
      end
    else
      # Logger.debug("No start byte, no packet in buffer")
      {%{state | last_packet: [], flag_byte_received: false}, false}
    end
    {state, data_list, valid_packet}
  end

  # defp get_data_length_from_sensor_header(header) do
  #   data_length = elem(header, 0) + (header,1) <<< 8)
  #   data_length &&& bnot(1 <<< 15) # clear the MS bit
  # end

  defp get_header_and_data_from_packet(packet) do
    [_flag_byte | packet] = packet
    [_protocol_byte | message] = packet
    header = get_header_from_packet(message)
    data = strip_header_from_packet(message)
    {header, data}
  end

  defp get_header_from_packet(header) do
    Enum.map(0..3, fn index -> Enum.at(header,index) end )
  end

  defp strip_header_from_packet(data) do
    # Strip the first 4 elements, return the remaining bytes as data
    Enum.reduce(0..3, data, fn _, data ->
      case data do
        [_ | tail] ->
          tail
        [] -> []
      end
    end)
  end

  defp process_data(state, data_list, report_id, status, delay_us, data_time_us) do
    #TODO - too much copy/paste to create a new report case
    {data_field, data} =
      case report_id do
        # @sensor_reportid_accelerometer ->
        #   # Accelerometer (0x01) - Q_point = 8
        #   accel = process_input_data_list(data_list, 8, 3)
        #   {:accel, %{accel: accel, status: status, delay_us: delay_us }}
        # @sensor_reportid_rotation_vector ->
        #   # Rotation Vector (0x05) - Q_point = 14
        #   quat = process_input_data_list(data_list, 14, 4)
        #   euler = Common.Utils.quat2euler(quat)
        #   dt = (delay_us - state.attitude.delay_us) + state.update_interval_ms
        #   euler_rate = if dt > 0 do
        #     {elem(euler, 0)/dt, elem(euler,1)/dt, elem(euler,2)/dt}
        #   else
        #     {0,0,0}
        #   end
        #   {:attitude, %{quat: quat, euler: euler, euler_rate: euler_rate, status: status, delay_us: delay_us}}
        @sensor_reportid_game_rotation_vector ->
          # AR Game Rotation Vector (0x29) - Q_point = 14
          quat_tuple = process_input_data_list(data_list, 14, 4)
          quat = %{
            x: elem(quat_tuple,0),
            y: elem(quat_tuple,1),
            z: elem(quat_tuple,2),
            w: elem(quat_tuple,3)
          }
          dt =
            case state.attitude.time_prev_us do
              nil ->
                1000000.0 # first reading, make time very large to the rate~=0
              time_prev_us->
                0.000001*((delay_us - state.attitude.delay_us) + (data_time_us - time_prev_us))
            end
          {quat, euler, euler_rate} = apply_rotation_with_sanity_check(quat, state.attitude.quat, state.attitude.euler, dt)
          # Logger.debug("quat: #{inspect(quat)}")
          # Logger.debug("euler: #{inspect(euler)}")
          # Logger.debug("euler rate: #{inspect(euler_rate)}")
          {:attitude, %{quat: quat, euler: euler, euler_rate: euler_rate, dt: dt, status: status, delay_us: delay_us, time_prev_us: data_time_us, available: true}}
        _ ->
          Logger.debug("Received message with id #{report_id}")
          {:unknown, nil}
      end

    state =
      case data_field do
        :unknown ->
          Logger.debug("Unknown data field #{inspect(data_field)}. Ignoring")
          state
        data_field ->
          %{state | data_field=>data}
      end
    # This should eventually move to the process handling the state process
    # Logger.debug(build_report_string(report_id, state))
    state
  end

  defp process_input_data_list(data, q_point, num_values) do
    data = Enum.slice(data, 0..num_values-1)
    denom = 1 <<< q_point
    Enum.map(data, fn x ->
      twos_comp_16(x)/denom end )
    |> List.to_tuple()
  end

  defp twos_comp_16(x) do
    <<si :: integer-signed-16>> = <<x :: integer-unsigned-16>>
    si
  end

  defp apply_rotation_with_sanity_check(quat, quat_prev, euler_prev, dt) do
    if (Bno080.Utils.quat_in_bounds?(quat)) do
      euler = Bno080.Utils.quat2euler(quat)
      {
        quat,
        euler,
        %{
          roll: (euler.roll - euler_prev.roll)/dt,
          pitch: (euler.pitch - euler_prev.pitch)/dt,
          yaw: (euler.yaw - euler_prev.yaw)/dt
        }
      }
    else
      # Logger.debug("#{inspect(quat)} out of bounds!")
      {quat_prev, euler_prev, %{roll: 0, pitch: 0, yaw: 0}}
    end
  end
end
