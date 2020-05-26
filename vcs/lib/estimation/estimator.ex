defmodule Estimation.Estimator do
  use GenServer
  require Logger
  @imu_watchdog_trigger 250
  @ins_watchdog_trigger 2000

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator")
    {:ok, process_id} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
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
        imu_watchdog_elapsed: 0,
        ins_watchdog_elapsed: 0,
        imu_watchdog_trigger: @imu_watchdog_trigger,
        ins_watchdog_trigger: @ins_watchdog_trigger,
        body_rate: %{},
        attitude: %{},
        velocity: %{},
        position: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(%{name: __MODULE__})
    MessageSorter.System.start_link()
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :attitude_body_rate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :position_velocity}, self())
    imu_loop_timer = Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    ins_loop_timer = Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    telemetry_loop_timer = Common.Utils.start_loop(self(), state.telemetry_loop_interval_ms, :telemetry_loop)
    imu_watchdog_elapsed = :erlang.monotonic_time(:millisecond)
    ins_watchdog_elapsed = :erlang.monotonic_time(:millisecond)
    state =
      %{state |
        imu_loop_timer: imu_loop_timer,
        ins_loop_timer: ins_loop_timer,
        telemetry_loop_timer: telemetry_loop_timer,
        imu_watchdog_elapsed: imu_watchdog_elapsed,
        ins_watchdog_elapsed: ins_watchdog_elapsed
       }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :attitude_body_rate}, pv_value_map}, state) do
    # Logger.debug("Estimator rx: #{inspect(pv_value_map)}")
    attitude = Map.get(pv_value_map, :attitude)
    body_rate = Map.get(pv_value_map, :body_rate)
    {attitude, body_rate, new_watchdog_elapsed} =
    if (attitude == nil) or (body_rate==nil) do
      {state.attitude, state.body_rate, state.imu_watchdog_elapsed}
    else
      new_watchdog_time = max(state.imu_watchdog_elapsed - 1.1*state.imu_loop_interval_ms, 0)
      {attitude, body_rate, new_watchdog_time}
    end
    state = %{state | attitude: attitude, body_rate: body_rate, imu_watchdog_elapsed: new_watchdog_elapsed}
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({{:pv_calculated, :position_velocity}, pv_value_map}, state) do
    # Logger.debug("Estimator rx: #{inspect(pv_value_map)}")
    position = Map.get(pv_value_map, :position)
    velocity = Map.get(pv_value_map, :velocity)
    {position, velocity, new_watchdog_elapsed} =
    if (position == nil) or (velocity==nil) do
      {state.position, state.velocity, state.ins_watchdog_elapsed}
    else
      new_watchdog_time = max(state.ins_watchdog_elapsed - 1.1*state.ins_loop_interval_ms, 0)
      {position, velocity, new_watchdog_time}
    end
    state = %{state | position: position, velocity: velocity, ins_watchdog_elapsed: new_watchdog_elapsed}
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:imu_loop, state) do
    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {{:pv_values, :attitude_body_rate}, %{attitude: state.attitude, body_rate: state.body_rate}, state.imu_loop_interval_ms/1000},
       {:pv_values, :attitude_body_rate},
      self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:ins_loop, state) do
    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {{:pv_values, :position_velocity}, %{position: state.position, velocity: state.velocity}, state.ins_loop_interval_ms/1000},
      {:pv_values, :position_velocity},
      self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:telemetry_loop, state) do
    Comms.Operator.send_global_msg_to_group(
      __MODULE__,
      {:pv_estimate, %{position: state.position, velocity: state.velocity, attitude: state.attitude, body_rate: state.body_rate}},
      :pv_estimate,
      self())
    {:noreply, state}
  end
end
