defmodule Estimation.Estimator do
  use GenServer
  require Logger
  @imu_watchdog_trigger 250
  @ins_watchdog_trigger 2000
  @agl_watchdog_trigger 2000
  @airspeed_watchdog_trigger 2000
  @min_speed_for_course 2

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
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
        watchdog_elapsed: %{imu: 0, ins: 0, agl: 0, airspeed: 0},
        watchdog_trigger: %{imu: @imu_watchdog_trigger, ins: @ins_watchdog_trigger, agl: @agl_watchdog_trigger, airspeed: @airspeed_watchdog_trigger},
        min_speed_for_course: @min_speed_for_course,
        bodyrate: %{},
        attitude: %{},
        velocity: %{},
        position: %{},
        agl: 0.0,
        airspeed: 0.0
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
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :agl}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :airspeed}, self())
    imu_loop_timer = Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    ins_loop_timer = Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    telemetry_loop_timer = Common.Utils.start_loop(self(), state.telemetry_loop_interval_ms, :telemetry_loop)
    imu_watchdog_elapsed = :erlang.monotonic_time(:millisecond)
    ins_watchdog_elapsed = :erlang.monotonic_time(:millisecond)
    watchdog_elapsed = %{state.watchdog_elapsed | imu: imu_watchdog_elapsed, ins: ins_watchdog_elapsed}
    state =
      %{state |
        imu_loop_timer: imu_loop_timer,
        ins_loop_timer: ins_loop_timer,
        telemetry_loop_timer: telemetry_loop_timer,
        watchdog_elapsed: watchdog_elapsed
       }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :attitude_bodyrate}, pv_value_map}, state) do
    # Logger.debug("Estimator rx: #{inspect(pv_value_map)}")
    attitude = Map.get(pv_value_map, :attitude)
    bodyrate = Map.get(pv_value_map, :bodyrate)
    {attitude, bodyrate, new_watchdog_elapsed} =
    if (attitude == nil) or (bodyrate==nil) do
      {state.attitude, state.bodyrate, state.watchdog_elapsed.imu}
    else
      new_watchdog_time = max(state.watchdog_elapsed.imu - 1.1*state.imu_loop_interval_ms, 0)
      {attitude, bodyrate, new_watchdog_time}
    end
    watchdog_elapsed = %{state.watchdog_elapsed | imu: new_watchdog_elapsed}
    state = %{state | attitude: attitude, bodyrate: bodyrate, watchdog_elapsed: watchdog_elapsed }
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({{:pv_calculated, :position_velocity}, pv_value_map}, state) do
    # Logger.debug("Estimator rx: #{inspect(pv_value_map)}")
    position = Map.get(pv_value_map, :position)
    velocity = Map.get(pv_value_map, :velocity)
    {position, velocity, new_watchdog_elapsed} =
    if (position == nil) or (velocity==nil) do
      {state.position, state.velocity, state.watchdog_elapsed.ins}
    else
      new_watchdog_time = max(state.watchdog_elapsed.ins - 1.1*state.ins_loop_interval_ms, 0)
      # If the velocity is below a threshold, we use yaw instead
      # velocity = Common.Utils.adjust_velocity_for_min_speed(velocity, Map.get(state.attitude, :yaw, 0), state.min_speed_for_course)
      {speed, course} = Common.Utils.get_speed_course_for_velocity(velocity.north, velocity.east, state.min_speed_for_course, Map.get(state.attitude, :yaw, 0))
      velocity = %{speed: speed, course: course}
      {position, velocity, new_watchdog_time}
    end
    watchdog_elapsed = %{state.watchdog_elapsed | ins: new_watchdog_elapsed}
    state = %{state | position: position, velocity: velocity, watchdog_elapsed: watchdog_elapsed}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :agl}, agl}, state) do
    new_watchdog_elapsed = max(state.watchdog_elapsed.agl - 1.1*state.ins_loop_interval_ms, 0)
    watchdog_elapsed = %{state.watchdog_elapsed | agl: new_watchdog_elapsed}
    state = %{state | watchdog_elapsed: watchdog_elapsed, agl: agl}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :airspeed}, airspeed}, state) do
    new_watchdog_elapsed = max(state.watchdog_elapsed.ins - 1.1*state.ins_loop_interval_ms, 0)
    watchdog_elapsed = %{state.watchdog_elapsed | airspeed: new_watchdog_elapsed}
    state = %{state | watchdog_elapsed: watchdog_elapsed, airspeed: airspeed}
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:imu_loop, state) do
    attitude = state.attitude
    bodyrate = state.bodyrate
    unless (Enum.empty?(attitude) or Enum.empty?(bodyrate)) do
      Comms.Operator.send_local_msg_to_group(
        __MODULE__,
        {{:pv_values, :attitude_bodyrate}, attitude, bodyrate, state.imu_loop_interval_ms/1000},
        {:pv_values, :attitude_bodyrate},
        self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:ins_loop, state) do
    position = state.position
    velocity = state.velocity
    unless Enum.empty?(position) or Enum.empty?(velocity) do
      position = Map.put(position, :agl, state.agl)
      velocity = Map.put(velocity, :airspeed, state.airspeed)
      Comms.Operator.send_local_msg_to_group(
        __MODULE__,
        {{:pv_values, :position_velocity}, position, velocity, state.ins_loop_interval_ms/1000},
        {:pv_values, :position_velocity},
        self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:telemetry_loop, state) do
    position = Map.put(state.position, :agl, state.agl)
    velocity = Map.put(state.velocity, :airspeed, state.airspeed)
    attitude = state.attitude
    bodyrate = state.bodyrate
    unless (Enum.empty?(position) or Enum.empty?(velocity) or Enum.empty?(attitude) or Enum.empty?(bodyrate)) do
      Comms.Operator.send_global_msg_to_group(
        __MODULE__,
        {:pv_estimate, %{position: position, velocity: velocity, attitude: attitude, bodyrate: bodyrate}},
        :pv_estimate,
        self())
    end
    {:noreply, state}
  end
end
