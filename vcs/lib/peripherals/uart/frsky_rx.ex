defmodule Peripherals.Uart.FrskyRx do
  use Bitwise
  use GenServer
  require Logger

  # @default_device_description "Arduino Micro"
  # @default_device_description "Feather M0"
  @default_baud 115_200
  @start_byte 0x0F
  @end_byte 0x00
  @end_byte_index 24
  @valid_frame_count_min 3
  @pw_mid 991.5
  @pw_half_range 819.5


  def start_link(config) do
    Logger.info("Start FrskyRx GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        device_description: config.device_description,
        start_byte_found: false,
        remaining_buffer: [],
        channel_values: [],
        failsafe_active: false,
        frame_lost: false,
        valid_frame_count: 0,
        new_frsky_data_to_publish: false,
        publish_rx_output_loop_timer: nil,
        publish_rx_output_loop_interval_ms: config.publish_rx_output_loop_interval_ms
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    frsky_port = Common.Utils.get_uart_devices_containing_string(state.device_description)
    case Circuits.UART.open(state.uart_ref, frsky_port, [speed: @default_baud, active: true, stop_bits: 2]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{frsky_port} is unavailable"
      _success ->
        Logger.debug("FrskyRx opened #{frsky_port}")
    end
    publish_rx_output_loop_timer = Common.Utils.start_loop(self(), state.publish_rx_output_loop_interval_ms, :publish_rx_output_loop)
    {:noreply, %{state | publish_rx_output_loop_timer: publish_rx_output_loop_timer}}
  end

  @impl GenServer
  def handle_info(:publish_rx_output_loop, state) do
    if (state.new_frsky_data_to_publish and !state.frame_lost) do
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, state.channel_values, state.failsafe_active}, :rx_output, self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    data_list = state.remaining_buffer ++ :binary.bin_to_list(data)
    state = parse_data_buffer(data_list, state)
    {:noreply, state}
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
    # The valid buffer should contain only the bytes after (and including) the start byte
    {state, parse_again} =
    if start_byte_found do
      end_byte = Enum.at(valid_buffer,@end_byte_index)
      unless end_byte == nil do
        if end_byte == @end_byte do
          # good checksum, drop entire message before we parse the next time
          # the payload does not include the message_group byte or the field_mask bytes
          # we can leave the crc bytes attached to the end of the payload buffer, because we know the length
          # the remaining_buffer is everything after the crc bytes
          payload_buffer = Enum.drop(valid_buffer,1)
          remaining_buffer = Enum.drop(payload_buffer, @end_byte_index)
          {frsky_channels, failsafe_active, frame_lost} = parse_good_message(payload_buffer)
          valid_frame_count = state.valid_frame_count + 1
          {channel_values, failsafe_active, frame_lost, new_frsky_data_to_publish, valid_frame_count} =
          if (valid_frame_count > @valid_frame_count_min) do
            # decrement valid_frame_count to avoid a gigantic number
            {frsky_channels, failsafe_active, frame_lost, true, valid_frame_count-1}
          else
            {state.channel_values, state.failsafe_active, state.frame_lost, false, valid_frame_count}
          end
          state = %{state |
                    remaining_buffer: remaining_buffer,
                    start_byte_found: false,
                    channel_values: channel_values,
                    failsafe_active: failsafe_active,
                    frame_lost: frame_lost,
                    valid_frame_count: valid_frame_count,
                    new_frsky_data_to_publish: new_frsky_data_to_publish}
          {state, true}
        else
          # bad checksum, which doesn't mean we lost some data
          # it could just mean that our "start byte" was just a data byte, so only
          # drop the start byte before we parse next
          remaining_buffer = Enum.drop(valid_buffer,1)
          state = %{state |
                    remaining_buffer: remaining_buffer,
                    start_byte_found: false,
                    valid_frame_count: 0
                   }
          {state, true}
        end
      else
        # we have not received enough data to parse a complete message
      # the next loop should try again with the same start_byte
      state = %{state |
                remaining_buffer: valid_buffer,
                start_byte_found: true}
      {state, false}
      end
    else
      state = %{state |
                remaining_buffer: valid_buffer,
               start_byte_found: false}
      {state, false}
    end
    if (parse_again) do
      parse_data_buffer(state.remaining_buffer, state)
    else
      state
    end
  end

  @spec parse_good_message(list()) :: list()
  defp parse_good_message(payload) do
    channels =
      [
      (Enum.at(payload,0)) + (Enum.at(payload,1)<<<8),
      (Enum.at(payload,1)>>>3) + (Enum.at(payload,2)<<<5),
      (Enum.at(payload,2)>>>6) + (Enum.at(payload,3)<<<2) + (Enum.at(payload,4)<<<10),
      (Enum.at(payload,4)>>>1) + (Enum.at(payload,5)<<<7),
      (Enum.at(payload,5)>>>4) + (Enum.at(payload,6)<<<4),
      (Enum.at(payload,6)>>>7) + (Enum.at(payload,7)<<<1) + (Enum.at(payload,8)<<<9),
      (Enum.at(payload,8)>>>2) + (Enum.at(payload,9)<<<6),
      (Enum.at(payload,9)>>>5) + (Enum.at(payload,10)<<<3),
      # (Enum.at(payload,11)) + (Enum.at(payload,12)<<<8),
      # (Enum.at(payload,12)>>>3) + (Enum.at(payload,13)<<<5),
      # (Enum.at(payload,13)>>>6) + (Enum.at(payload,14)<<<2) + (Enum.at(payload,15)<<<10),
      # (Enum.at(payload,15)>>>1) + (Enum.at(payload,16)<<<7),
      # (Enum.at(payload,16)>>>4) + (Enum.at(payload,17)<<<4),
      # (Enum.at(payload,17)>>>7) + (Enum.at(payload,18)<<<1) + (Enum.at(payload,19)<<<9),
      # (Enum.at(payload,19)>>>2) + (Enum.at(payload,20)<<<6),
      # (Enum.at(payload,20)>>>5) + (Enum.at(payload,21)<<<3),
      ]
    channels = Enum.reduce(Enum.reverse(channels), [], fn (value, acc) ->
      # [(value &&& 0x07FF)] ++ acc
      [((value &&& 0x07FF) -@pw_mid)/@pw_half_range] ++ acc
    end)
    flag_byte = Enum.at(payload,22)
    failsafe_active = ((flag_byte &&& 0x08) > 0)
    frame_lost = ((flag_byte &&& 0x04) > 0)
    {channels,failsafe_active, frame_lost}
	end

  @impl GenServer
  def handle_call({:get_channel_value, channel}, _from, state) do
    value = Enum.at(state.channel_values,channel)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call(:is_failsafe_active, _from, state) do
    {:reply, state.failsafe_active, state}
  end

  @impl GenServer
  def handle_call(:is_frame_lost, _from ,state) do
    {:reply, state.frame_lost, state}
  end

  def get_value_for_channel(channel) do
    GenServer.call(__MODULE__, {:get_channel_value, channel})
  end

  def failsafe_active?() do
    GenServer.call(__MODULE__, :is_failsafe_active)
  end

  def frame_lost?() do
    GenServer.call(__MODULE__, :is_frame_lost)
  end
end
