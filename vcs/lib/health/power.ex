defmodule Health.Power do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Health.Monitor")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        status_loop_interval_ms: config.status_loop_interval_ms,
        watchdogs: config.watchdogs,
        watchdog_interval_ms: config.watchdog_interval_ms,
        batteries: %{}
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :battery_status, self())
    Common.Utils.start_loop(self(), state.status_loop_interval_ms, :status_loop)
    Enum.each(state.watchdogs, fn watchdog ->
      Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(watchdog, state.watchdog_interval_ms))
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:battery_status, battery}, state) do
    # Logger.debug("rx bat: #{inspect(battery)}")
    battery_id = Health.Hardware.Battery.get_battery_id(battery)
    # Logger.info("battery status id: #{battery_id}")
    batteries = Map.put(state.batteries, battery_id, battery)
    {:noreply, %{state | batteries: batteries}}
  end

  @impl GenServer
  def handle_info(:status_loop, state) do
    unless Enum.empty?(state.batteries) do
      Peripherals.Uart.Telemetry.Operator.store_data(%{batteries: state.batteries})
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_battery, battery_id}, _from, state) do
    Logger.info("get battery: #{battery_id}")
    {:reply, Map.get(state.batteries, battery_id), state}
  end

  @spec get_battery(atom) :: map()
  def get_battery(id) do
    Common.Utils.safe_call(__MODULE__, {:get_battery, id}, 200, -1)
  end
end
