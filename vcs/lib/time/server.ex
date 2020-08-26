defmodule Time.Server do
  use GenServer
  require Logger

  @gps_epoch ~U[1980-01-01 00:00:00Z]

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
        gps_time_source: nil,
        system_time_ms: nil,
        gps_time: nil,
        datetime: nil
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :gps_time_source, self())
    Comms.Operator.join_group(__MODULE__, :gps_time, self())
    # Common.Utils.start_loop(self(), state.server_loop_interval_ms, :server_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:gps_time_source, gps_time_since_epoch_ns}, state) do
    {gps_time_source, system_time} = calculate_gps_time(gps_time_since_epoch_ns)
    Logger.debug("gps time UTC: #{inspect(gps_time_source)}")
    state = %{state |
              gps_time_source: gps_time_source,
              gps_time: gps_time_source,
              system_time_ms: system_time
             }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:gps_time, gps_time_since_epoch_ns}, state) do
    {gps_time, system_time} = calculate_gps_time(gps_time_since_epoch_ns)
    Logger.debug("gps time UTC: #{inspect(gps_time)}")
    state = %{state |
              gps_time: gps_time,
              system_time_ms: system_time
             }
    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_gps_time_source, _from, state) do
    {:reply, state.gps_time_source, state}
  end

  @impl GenServer
  def handle_call(:get_time, _from, state) do
    Logger.info("get time")
    current_time = :os.system_time(:millisecond)
    dt_ms = current_time - Map.get(state, :system_time_ms,0)
    source_time = if is_nil(state.gps_time), do: @gps_epoch, else: state.gps_time
    time = DateTime.add(source_time, dt_ms, :millisecond)
    {:reply, time, state}
  end

  @spec get_gps_time_source() :: struct()
  def get_gps_time_source() do
    Common.Utils.safe_call(__MODULE__, :get_gps_time_source, 1000, nil)
  end

  @spec get_time() :: struct()
  def get_time() do
    Common.Utils.safe_call(__MODULE__, :get_time, 1000, nil)
  end

  @spec calculate_gps_time(integer()) :: tuple()
  def calculate_gps_time(time_since_gps_epoch_ns) do
    system_time= :os.system_time(:millisecond)
    Logger.debug("received gps_time: #{time_since_gps_epoch_ns}")
    gps_time= DateTime.add(@gps_epoch, time_since_gps_epoch_ns, :nanosecond)
    {gps_time, system_time}
  end
end
