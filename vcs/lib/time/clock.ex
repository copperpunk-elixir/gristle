defmodule Time.Clock do
  require Logger

  defstruct [system_time_ms: nil, source_time: nil]

  @epoch ~U[1980-01-01 00:00:00Z]

  def new() do
    %Time.Clock{}
  end

  @spec set_time_ns(struct(), integer()) :: struct()
  def set_time_ns(clock, time_ns) do
    # Logger.debug("clock set_time_ns: #{time_ns}")
    source_time = calculate_source_time(time_ns)
    %{clock | source_time: source_time, system_time_ms: :os.system_time(:millisecond)}
  end

  @spec set_datetime(struct(), struct()) :: struct()
  def set_datetime(clock, time) do
    # Logger.debug("clock set_datetime: #{inspect(time)}")
    %{clock | source_time: time, system_time_ms: :os.system_time(:millisecond)}
  end

  @spec utc_now(struct()) :: struct()
  def utc_now(clock) do
    # Logger.debug("utc_now: #{inspect(clock)}")
    if is_nil(clock.system_time_ms) or is_nil(clock.source_time) do
      @epoch
    else
      current_time = :os.system_time(:millisecond)
      dt_ms = current_time - clock.system_time_ms
      DateTime.add(clock.source_time, dt_ms, :millisecond)
    end
  end

  @spec calculate_source_time(integer()) :: tuple()
  def calculate_source_time(time_since_epoch_ns) do
    DateTime.add(@epoch, time_since_epoch_ns, :nanosecond)
  end

  @spec get_epoch() :: struct()
  def get_epoch() do
    @epoch
  end

end
