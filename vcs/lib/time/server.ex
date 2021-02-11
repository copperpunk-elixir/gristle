defmodule Time.Server do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Time.Server GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    state = %{
      clock: Time.Clock.new()
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :gps_time_source, self())
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :server_loop_interval_ms), :server_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:gps_time_source, gps_time_since_epoch_ns}, state) do
    # Logger.debug("gps time source: #{gps_time_since_epoch_ns}")
    clock = Time.Clock.set_time_ns(state.clock, gps_time_since_epoch_ns)
    {:noreply, %{state | clock: clock}}
  end

  @impl GenServer
  def handle_info(:server_loop, state) do
    time = Time.Clock.utc_now(state.clock)
    # Logger.debug("send gps time: #{inspect(time)}")
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:gps_time, time}, self())
    {:noreply, state}
  end

  @spec get_time_day(struct()) :: tuple()
  def get_time_day(clock) do
    time = Time.Clock.utc_now(clock)
    day = Date.from_erl!({time.year, time.month, time.day})
    {time, day}
  end
end
