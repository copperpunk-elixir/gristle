defmodule Peripherals.Uart.Command.Dsm do
  require Logger
  use Bitwise

  @pw_mid 991
  @pw_half_range 819
  @pw_min 172
  @pw_max 1810

  @start_byte_1 0x00
  @start_byte_2 0x00
  @msg_length 14

  @got_none 0
	@got_sync1 1
	@got_sync2 2



  defstruct [state: @got_none, count: 0, payload_rev: [], payload_ready: false, channel_map: %{}, channel_count: 0]

  @spec new() :: struct()
  def new() do
    %Peripherals.Uart.Command.Dsm{}
  end

  @spec parse(struct(), integer()) :: struct()
  def parse(dsm, byte) do
    state = dsm.state
    # Logger.debug("state: #{state}")
    cond do
      state == @got_none and byte == @start_byte_1 -> %{dsm | state: @got_sync1, count: 0}
      state == @got_sync1 ->
        if (byte == @start_byte_2) do
          %{dsm | state: @got_sync2, payload_rev: []}
        else
          %{dsm | state: @got_none}
        end
      state == @got_sync2 ->
        payload_rev = [byte] ++ dsm.payload_rev
        count = dsm.count + 1
        dsm = cond do
          (count == @msg_length) ->
            dsm = parse_payload(dsm, payload_rev)
            %{dsm | state: @got_none}
          (count < @msg_length) -> dsm
          true -> %{dsm | state: @got_none}
        end

        %{dsm | count: count, payload_rev: payload_rev}
      true ->
        # Garbage byte
        # Logger.warn("parse unexpected condition")
        %{dsm | state: @got_none}
    end
  end

  @spec parse_payload(struct(), list()) :: struct()
  def parse_payload(dsm, payload_rev) do
    payload = Enum.reverse(payload_rev)
    payload_words = Enum.chunk_every(payload, 2)
    first_word = Enum.at(payload_words,0)
    {channel_map, channel_count} =
    case get_msg_id(first_word) do
      0 ->
        {channels, valid_count} = extract_channels(payload_words, dsm.channel_map)
        if (valid_count == 7), do: {channels, 7}, else: {%{}, 0}
      1 ->
        {channels, valid_count} = extract_channels(payload_words, dsm.channel_map)
        if (valid_count == 7), do: {channels, dsm.channel_count + 7}, else: {%{}, 0}
      _other -> {%{}, 0}
    end
    # Logger.debug("map: #{inspect(channel_map)}")
    payload_ready = if channel_count == 14, do: true, else: false
    %{dsm | payload_ready: payload_ready, channel_count: channel_count, channel_map: channel_map}
  end

  @spec extract_channels(list(), map()) :: struct()
  def extract_channels(payload_words, channel_map) do
    Enum.reduce(payload_words, {channel_map, 0}, fn ([msb, lsb], {channels, count}) ->
      word = (msb<<<8) + lsb
      channel_id = get_channel_id(word)
      channel_value = get_channel_value(word)
      # Logger.debug("#{word}/#{channel_id}/#{channel_value}")
      if (channel_value >= @pw_min) and (channel_value <=@pw_max) and channel_id < 14 do
        {Map.put(channels, channel_id, channel_value), count+1}
      else
        {channels, count}
      end
    end)
  end

  @spec get_channel_id(integer()) :: integer()
  def get_channel_id(word) do
    Bitwise.>>>(word,10)
    |> Bitwise.&&&(0x1F)
  end

  @spec get_msg_id(integer()) :: integer()
  def get_msg_id(word) do
    [msb,_lsb] = word
    Bitwise.>>>(msb,7)
  end

  @spec get_channel_value(integer()) :: integer()
  def get_channel_value(word) do
    Bitwise.&&&(word, 0x03FF) * 2
  end

  @spec get_channels(struct()) :: list()
  def get_channels(dsm) do
    Enum.reduce(13..0, [], fn (ch_index, acc) ->
      channel_pw = Map.get(dsm.channel_map, ch_index, 0)
      channel_value = (channel_pw - @pw_mid) / @pw_half_range
      [channel_value] ++ acc
    end)
  end

  @spec clear(struct()) :: struct()
  def clear(dsm) do
    %{dsm | payload_ready: false}
  end

end
