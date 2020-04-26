defmodule Estimation.Estimator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator")
    {:ok, process_id} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    begin()
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        imu_loop_timer: nil,
        imu_loop_interval_ms: config.imu_loop_interval_ms,
        imu_loop_timeout_ms: config.imu_loop_timeout_ms,
        ins_loop_timer: nil,
        ins_loop_interval_ms: config.ins_loop_interval_ms,
        ins_loop_timeout_ms: config.ins_loop_timeout_ms,
        telemetry_loop_timer: nil,
        telemetry_loop_interval_ms: config.telemetry_loop_interval_ms,
        estimator_health: :unknown,
        watchdog_elapsed: %{imu: 0, ins: 0},
        attitude_rate: %{},
        attitude: %{},
        velocity: %{},
        position: %{}
     }}
  end

  def begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    MessageSorter.System.start_link()
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :attitude_attitude_rate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :position_velocity}, self())
    GenServer.cast(self(), :start_imu_loop)
    GenServer.cast(self(), :start_ins_loop)
    GenServer.cast(self(), :start_telemetry_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_imu_loop, state) do
    imu_loop_timer = Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    state = %{state | imu_loop_timer: imu_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_imu_loop, state) do
    imu_loop_timer = Common.Utils.stop_loop(state.imu_loop_timer)
    state = %{state | imu_loop_timer: imu_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_ins_loop, state) do
    ins_loop_timer = Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    state = %{state | ins_loop_timer: ins_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_ins_loop, state) do
    ins_loop_timer = Common.Utils.stop_loop(state.ins_loop_timer)
    state = %{state | ins_loop_timer: ins_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_telemetry_loop, state) do
    telemetry_loop_timer = Common.Utils.start_loop(self(), state.telemetry_loop_interval_ms, :telemetry_loop)
    state = %{state | telemetry_loop_timer: telemetry_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_telemetry_loop, state) do
    telemetry_loop_timer = Common.Utils.stop_loop(state.telemetry_loop_timer)
    state = %{state | telemetry_loop_timer: telemetry_loop_timer}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :attitude_attitude_rate}, pv_value_map}, state) do
    Logger.debug("Estimator rx: #{inspect(pv_value_map)}")

    attitude = Map.get(pv_value_map, :attitude)
    attitude_rate = Map.get(pv_value_map, :attitude_rate)
    {attitude, attitude_rate, new_watchdog_elapsed} =
    if (attitude == nil) or (attitude_rate==nil) do
      {state.attitude, state.attitude_rate, 0}
    else
      new_watchdog_time = max(state.watchdog_elapsed.ins - state.imu_loop_interval_ms, 0)
      {attitude, attitude_rate, new_watchdog_time}
    end
    state = %{state | attitude: attitude, attitude_rate: attitude_rate, watchdog_elapsed: Map.put(state.watchdog_elapsed, :imu, new_watchdog_elapsed)}
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({{:pv_calculated, :position_velocity}, pv_value_map}, state) do
    Logger.debug("Estimator rx: #{inspect(pv_value_map)}")

    position = Map.get(pv_value_map, :position)
    velocity = Map.get(pv_value_map, :velocity)
    {position, velocity, new_watchdog_elapsed} =
    if (position == nil) or (velocity==nil) do
      {state.position, state.velocity, 0}
    else
      new_watchdog_time = max(state.watchdog_elapsed.ins - state.ins_loop_interval_ms, 0)
      {position, velocity, new_watchdog_time}
    end
    state = %{state | position: position, velocity: velocity, watchdog_elapsed: Map.put(state.watchdog_elapsed, :imu, new_watchdog_elapsed)}
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:imu_loop, state) do
    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {{:pv_values, :attitude_attitude_rate}, %{attitude: state.attitude, attitude_rate: state.attitude_rate}, state.imu_loop_interval_ms},
       {:pv_values, :attitude_attitude_rate},
       self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:ins_loop, state) do
    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {{:pv_values, :position_velocity}, %{position: state.position, velocity: state.velocity}, state.ins_loop_interval_ms},
      {:pv_values, :position_velocity},
      self())

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:telemetry_loop, state) do
    {:noreply, state}
  end
end