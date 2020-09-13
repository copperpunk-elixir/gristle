defmodule Time.Server do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Time.Server")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        server_loop_interval_ms: config.server_loop_interval_ms,
        clock: Time.Clock.new()
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :gps_time_source, self())
    Comms.Operator.join_group(__MODULE__, :gps_time, self())
    Common.Utils.start_loop(self(), state.server_loop_interval_ms, :server_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:gps_time_source, gps_time_since_epoch_ns}, state) do
    clock = Time.Clock.set_time_ns(state.clock, gps_time_since_epoch_ns)
    {:noreply, %{state | clock: clock}}
  end

  @impl GenServer
  def handle_cast({:gps_time, gps_time}, state) do
    # {gps_time, system_time} = calculate_gps_time(gps_time_since_epoch_ns)
    # Logger.debug("gps time UTC: #{inspect(gps_time)}")
    clock = Time.Clock.set_datetime(state.clock, gps_time)
    {:noreply, %{state | clock: clock}}
  end

  @impl GenServer
  def handle_info(:server_loop, state) do
    time = Time.Clock.utc_now(state.clock)
    Logger.info("send gps time: #{inspect(time)}")
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:gps_time, time}, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_gps_time_source, _from, state) do
    {:reply, state.clock.source_time, state}
  end

  @impl GenServer
  def handle_call(:get_time, _from, state) do
    time = Time.Clock.utc_now(state.clock)
    {:reply, time, state}
  end

  @impl GenServer
  def handle_call(:get_time_day, _from, state) do
    time = Time.Clock.utc_now(state.clock)
    day = Date.from_erl!({time.year, time.month, time.day})
    {:reply, {time, day}, state}
  end

  @spec get_gps_time_source() :: struct()
  def get_gps_time_source() do
    Common.Utils.safe_call(__MODULE__, :get_gps_time_source, 100, nil)
  end

  @spec get_time() :: struct()
  def get_time() do
    Common.Utils.safe_call(__MODULE__, :get_time, 100, nil)
  end

  @spec get_time_day() :: struct()
  def get_time_day() do
    Common.Utils.safe_call(__MODULE__, :get_time_day, 100, nil)
  end
end
