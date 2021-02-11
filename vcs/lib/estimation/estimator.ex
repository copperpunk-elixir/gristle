defmodule Estimation.Estimator do
  use GenServer
  require Logger
  @min_speed_for_course 0.1

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator GenServer")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    state = %{
      watchdog_fed: %{att_rate: false, pos_vel: false, range: false, airspeed: false},
      imu_loop_interval_ms: Keyword.fetch!(config, :imu_loop_interval_ms),
      ins_loop_interval_ms: Keyword.fetch!(config, :ins_loop_interval_ms),
      min_speed_for_course: @min_speed_for_course,
      bodyrate: %{},
      attitude: %{},
      velocity: %{},
      position: %{},
      vertical_velocity: 0.0,
      agl: 0.0,
      airspeed: 0.0,
      laser_alt_ekf: Estimation.LaserAltimeterEkf.new([]),
      # ground_altitude: 0.0
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:estimation_calculated, :attitude_bodyrate}, self())
    Comms.Operator.join_group(__MODULE__, {:estimation_calculated, :position_velocity}, self())
    Comms.Operator.join_group(__MODULE__, {:estimation_calculated, :airspeed}, self())
    Comms.Operator.join_group(__MODULE__, {:estimation_measured, :range}, self())
    Comms.Operator.join_group(__MODULE__, {:watchdog_status, :range}, self())
    Comms.Operator.join_group(__MODULE__, {:watchdog_status, :att_rate}, self())
    Comms.Operator.join_group(__MODULE__, {:watchdog_status, :pos_vel}, self())
    Comms.Operator.join_group(__MODULE__, {:watchdog_status, :airspeed}, self())
    Common.Utils.start_loop(self(), state.imu_loop_interval_ms, :imu_loop)
    Common.Utils.start_loop(self(), state.ins_loop_interval_ms, :ins_loop)
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :sca_values_slow_loop_interval_ms), :sca_values_slow_loop)
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:att_rate, Keyword.fetch!(config, :att_rate_expected_interval_ms)))
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:pos_vel, Keyword.fetch!(config, :pos_vel_expected_interval_ms)))
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:airspeed, Keyword.fetch!(config, :airspeed_expected_interval_ms)))
    Watchdog.Active.start_link(Configuration.Module.Watchdog.get_local(:range, Keyword.fetch!(config, :range_expected_interval_ms)))
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:estimation_calculated, :attitude_bodyrate}, values}, state) do
    # Logger.debug("Estimator rx: #{inspect(values)}")
    attitude = Map.get(values, :attitude)
    bodyrate = Map.get(values, :bodyrate)
    {attitude, bodyrate} =
    if is_nil(attitude) or is_nil(bodyrate) do
      {state.attitude, state.bodyrate}
    else
      Watchdog.Active.feed(:att_rate)
      {attitude, bodyrate}
    end
    state = %{state | attitude: attitude, bodyrate: bodyrate}
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({{:estimation_calculated, :position_velocity}, values}, state) do
    # Logger.debug("Estimator rx: #{inspect(values)}")
    position = Map.get(values, :position)
    velocity = Map.get(values, :velocity)
    {position, velocity, update_agl} =
    if is_nil(position) or is_nil(velocity) do
      {state.position, state.velocity, false}
    else
      # position = Map.put_new(position, :ground_altitude, position.altitude)
      Watchdog.Active.feed(:pos_vel)
      # If the velocity is below a threshold, we use yaw instead
      {speed, course} = Common.Utils.Motion.get_speed_course_for_velocity(velocity.north, velocity.east, state.min_speed_for_course, Map.get(state.attitude, :yaw, 0))
      # Logger.debug("course/yaw: #{Common.Utils.eftb_deg(course,1)}/#{Common.Utils.eftb_deg(Map.get(state.attitude, :yaw, 0),2)}")
      velocity = %{speed: speed, course: course, vertical: -velocity.down}
      {position, velocity, true}
    end

    {ekf, ground_altitude, agl} =
    if state.watchdog_fed.range and update_agl do
      ekf = update_ekf(state.laser_alt_ekf, state.attitude, velocity)
      agl = Estimation.LaserAltimeterEkf.agl(ekf)
      ground_altitude = position.altitude - agl
      {ekf, ground_altitude, agl}
    else
      ground_altitude = Map.get(state, :ground_altitude, Map.get(position, :altitude, 0))
      {state.laser_alt_ekf, ground_altitude, position.altitude - ground_altitude}
    end
    state = if ground_altitude != 0, do: Map.put(state, :ground_altitude, ground_altitude), else: state
    state = %{state | position: position, velocity: velocity, laser_alt_ekf: ekf, agl: agl}
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:estimation_calculated, :airspeed}, airspeed}, state) do
    {:noreply, %{state | airspeed: max(airspeed, 0)}}
  end

  @impl GenServer
  def handle_cast({{:estimation_measured, :range}, range}, state) do
    ekf = if !state.watchdog_fed.range do
      # We went from an invalid range to a valid one. Reset the EFK
      Estimation.LaserAltimeterEkf.reset(state.laser_alt_ekf, range)
    else
      Estimation.LaserAltimeterEkf.update(state.laser_alt_ekf, range)
    end
    # Logger.debug("rx range: #{range}")
    Watchdog.Active.feed(:range)
    # Logger.debug("agl: #{Estimation.LaserAltimeterEkf.agl(ekf)}")
    {:noreply, %{state | laser_alt_ekf: ekf}}
  end

  @impl GenServer
  def handle_cast({{:watchdog_status, name}, is_fed}, state) do
    watchdog_fed = Map.put(state.watchdog_fed, name, is_fed)
    Logger.debug("rx watchdog state for #{name}: #{is_fed}")
    {:noreply, %{state | watchdog_fed: watchdog_fed}}
  end

  @impl GenServer
  def handle_info(:imu_loop, state) do
    if state.watchdog_fed.att_rate do
      attitude = state.attitude
      bodyrate = state.bodyrate
      unless Enum.empty?(attitude) or Enum.empty?(bodyrate) do
        Peripherals.Uart.Telemetry.Operator.store_data(%{attitude: attitude})
        Comms.Operator.send_local_msg_to_group(
          __MODULE__,
          {{:estimation_values, :attitude_bodyrate}, attitude, bodyrate, state.imu_loop_interval_ms/1000},
          self())
      end
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:ins_loop, state) do
    if state.watchdog_fed.pos_vel do
      position = state.position
      velocity = Map.take(state.velocity, [:speed, :course, :vertical])
      unless Enum.empty?(position) or Enum.empty?(velocity) do
        position = Map.put(position, :agl, state.agl)
        airspeed = if (state.airspeed > 1.0), do: state.airspeed, else: velocity.speed
        velocity = Map.put(velocity, :airspeed, airspeed)
        Peripherals.Uart.Telemetry.Operator.store_data(%{position: position, velocity: velocity})
        Comms.Operator.send_local_msg_to_group(
          __MODULE__,
          {{:estimation_values, :position_velocity}, position, velocity, state.ins_loop_interval_ms/1000},
          self())
      end
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:sca_values_slow_loop, state) do
    position = state.position
    velocity = Map.take(state.velocity, [:speed, :course])
    unless Enum.empty?(position) or Enum.empty?(velocity) do
      airspeed = if (state.airspeed > 1.0), do: state.airspeed, else: velocity.speed
      values = Map.put(velocity, :airspeed, airspeed)
      |> Map.put(:altitude, position.altitude)
      Comms.Operator.send_local_msg_to_group(
        __MODULE__,
        {:sca_values_slow, values},
        self())
    end
    {:noreply, state}
  end

  @spec update_ekf(struct(), map(), map()) :: struct()
  def update_ekf(ekf, attitude, velocity) do
    roll = Map.get(attitude, :roll, 0)
    pitch = Map.get(attitude, :pitch, 0)
    zdot = Map.get(velocity, :vertical, 0)
    # Logger.debug("rpv: #{Common.Utils.eftb_deg(roll,1)}/#{Common.Utils.eftb_deg(pitch,1)}/#{zdot}")
    Estimation.LaserAltimeterEkf.predict(ekf, roll, pitch, zdot)
  end
end
