defmodule Estimation.Estimator do
  use GenServer
  require Logger
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
        imu_loop_interval_ms: config.imu_loop_interval_ms,
        ins_loop_interval_ms: config.ins_loop_interval_ms,
        pv_3_local_loop_interval_ms: config.pv_3_local_loop_interval_ms,
        att_rate_expected_interval_ms: config.att_rate_expected_interval_ms,
        pos_vel_expected_interval_ms: config.pos_vel_expected_interval_ms,
        range_expected_interval_ms: config.range_expected_interval_ms,
        airspeed_expected_interval_ms: config.airspeed_expected_interval_ms,
        watchdog_fed: %{attrate: false, pos_vel: false, range: false, airspeed: false},
        estimator_health: :unknown,
        min_speed_for_course: @min_speed_for_course,
        bodyrate: %{},
        attitude: %{},
        velocity: %{},
        position: %{},
        vertical_velocity: 0.0,
        agl: 0.0,
        airspeed: 0.0,
        laser_alt_ekf: Estimation.LaserAltimeterEkf.new(%{}),
        ground_altitude: 0.0
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
    Comms.Operator.join_group(__MODULE__, {:pv_calculated, :airspeed}, self())
    Comms.Operator.join_group(__MODULE__, {:pv_measured, :range}, self())
    Comms.Operator.join_group(__MODULE__, {:watchdog, :range}, self())
    Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:att_rate, state.att_rate_expected_interval_ms))
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:pos_vel, state.pos_vel_expected_interval_ms))
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:airspeed, state.airspeed_expected_interval_ms))
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:range, state.range_expected_interval_ms))
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :attitude_bodyrate}, pv_value_map}, state) do
    # Logger.debug("Estimator rx: #{inspect(pv_value_map)}")
    attitude = Map.get(pv_value_map, :attitude)
    bodyrate = Map.get(pv_value_map, :bodyrate)
    {attitude, bodyrate} =
    if (attitude == nil) or (bodyrate==nil) do
      {state.attitude, state.bodyrate}
    else
      Watchdog.Active.feed(:att_rate)
      {attitude, bodyrate}
    end
    state = %{state | attitude: attitude, bodyrate: bodyrate}
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({{:pv_calculated, :position_velocity}, pv_value_map}, state) do
    # Logger.debug("Estimator rx: #{inspect(pv_value_map)}")
    position = Map.get(pv_value_map, :position)
    velocity = Map.get(pv_value_map, :velocity)
    {position, velocity} =
    if (position == nil) or (velocity==nil) do
      {state.position, state.velocity}
    else
      position = Map.put(position, :altitude, position.altitude)
      Watchdog.Active.feed(:pos_vel)
      # If the velocity is below a threshold, we use yaw instead
      {speed, course} = Common.Utils.get_speed_course_for_velocity(velocity.north, velocity.east, state.min_speed_for_course, Map.get(state.attitude, :yaw, 0))
      velocity = %{speed: speed, course: course, vertical: -velocity.down}
      {position, velocity}
    end

    {ekf, ground_altitude, agl} =
    if (state.watchdog_fed.range == true) do
      ekf =update_ekf(state.laser_alt_ekf, state.attitude, velocity)
      agl = Estimation.LaserAltimeterEkf.agl(ekf)
      ground_altitude = position.altitude - agl
      {ekf, ground_altitude, agl}
    else
      {state.laser_alt_ekf, state.ground_altitude, position.altitude - state.ground_altitude}
    end
    state = %{state | position: position, velocity: velocity, laser_alt_ekf: ekf, ground_altitude: ground_altitude, agl: agl}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_calculated, :airspeed}, airspeed}, state) do
    {:noreply, %{state | airspeed: max(airspeed, 0)}}
  end

  @impl GenServer
  def handle_cast({{:pv_measured, :range}, range}, state) do
    ekf = if (state.watchdog_fed.range == false) do
      # We went from an invalid range to a valid one. Reset the EFK
      Estimation.LaserAltimeterEkf.reset(state.laser_alt_ekf, range)
    else
      Estimation.LaserAltimeterEkf.update(state.laser_alt_ekf, range)
    end
    # Logger.info("rx range: #{range}")
    Watchdog.Active.feed(:range)
    # Logger.info("agl: #{Estimation.LaserAltimeterEkf.agl(ekf)}")
    {:noreply, %{state | laser_alt_ekf: ekf}}
  end

  @impl GenServer
  def handle_cast({{:watchdog_status, name}, is_fed}, state) do
    watchdog_fed = Map.put(state.watchdog_fed, name, is_fed)
    {:noreply, %{state | watchdog_fed: watchdog_fed}}
  end

  @impl GenServer
  def handle_info(:imu_loop, state) do
    attitude = state.attitude
    bodyrate = state.bodyrate
    unless (Enum.empty?(attitude) or Enum.empty?(bodyrate)) do
      Telemetry.Operator.store_data(%{attitude: attitude})
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
    velocity = Map.take(state.velocity, [:speed, :course])
    unless Enum.empty?(position) or Enum.empty?(velocity) do
      position = Map.put(position, :agl, state.agl)
      airspeed = state.airspeed
      airspeed = if (airspeed > 1.0), do: airspeed, else: velocity.speed
      velocity = Map.put(velocity, :airspeed, airspeed)
      Telemetry.Operator.store_data(%{position: position, velocity: velocity})
      Comms.Operator.send_local_msg_to_group(
        __MODULE__,
        {{:pv_values, :position_velocity}, position, velocity, state.ins_loop_interval_ms/1000},
        {:pv_values, :position_velocity},
        self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:pv_3_local_loop, state) do
    position = state.position
    velocity = Map.take(state.velocity, [:speed, :course])
    unless Enum.empty?(position) or Enum.empty?(velocity) do

      airspeed = state.airspeed
      airspeed = if (airspeed > 1.0), do: airspeed, else: velocity.speed
      pv_3_values = Map.put(velocity, :airspeed, airspeed)
      |> Map.put(:altitude, position.altitude)
      Comms.Operator.send_local_msg_to_group(
        __MODULE__,
        {:pv_3_local, pv_3_values},
        self())
    end
    {:noreply, state}
  end


  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    key = Common.Utils.assert_list(key)
    value = get_in(state, key)
    {:reply, value, state}
  end

  @spec update_ekf(struct(), map(), map()) :: struct()
  def update_ekf(ekf, attitude, velocity) do
    roll = Map.get(attitude, :roll, 0)
    pitch = Map.get(attitude, :pitch, 0)
    zdot = Map.get(velocity, :vertical, 0)
    # Logger.debug("rpv: #{Common.Utils.eftb_deg(roll,1)}/#{Common.Utils.eftb_deg(pitch,1)}/#{zdot}")
    Estimation.LaserAltimeterEkf.predict(ekf, roll, pitch, zdot)
  end

  @spec get_value(any()) :: any()
  def get_value(key) do
    GenServer.call(__MODULE__, {:get, key})
  end
end
