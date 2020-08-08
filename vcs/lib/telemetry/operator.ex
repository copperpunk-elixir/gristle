defmodule Telemetry.Operator do
  use GenServer
  require Logger

  @default_baud 57_600

  def start_link(config) do
    Logger.debug("Start Telemetry.Operator")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        device_description: config.device_description,
        ublox: Telemetry.Ublox.new(),
        fast_loop_interval_ms: config.fast_loop_interval_ms,
        medium_loop_interval_ms: config.medium_loop_interval_ms,
        slow_loop_interval_ms: config.slow_loop_interval_ms,
        accel: %{},
        bodyrate: %{},
        attitude: %{},
        velocity: %{},
        position: %{},
        level_1: %{},
        level_2: %{},
        level_3: %{},
        control_state: nil
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
    telemetry_port = Common.Utils.get_uart_devices_containing_string(state.device_description)
    case Circuits.UART.open(state.uart_ref, telemetry_port, [speed: @default_baud, active: true]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{telemetry_port} is unavailable"
      _success ->
        Logger.debug("TelemetryRx opened #{telemetry_port}")
    end
    # fast_loop_timer = nil#Common.Utils.start_loop(self(), state.fast_loop_interval_ms, :fast_loop)
    # medium_loop_timer = nil#Common.Utils.start_loop(self(), state.medium_loop_interval_ms, :medium_loop)
    Common.Utils.start_loop(self(), state.slow_loop_interval_ms, :slow_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:store_data, data_map}, state) do
    state = Enum.reduce(data_map, state, fn ({key, value}, acc) ->
      Map.put(acc, key, value)
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send_message, message}, state) do
    Circuits.UART.write(state.uart_ref, message)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_values, key_list}, _from, state) do
    {:reply, Map.take(state, key_list), state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.info("rx'd data: #{inspect(data)}")
    ublox = parse(state.ublox, :binary.bin_to_list(data))
    {:noreply, %{state | ublox: ublox}}
  end

  @impl GenServer
  def handle_info(:slow_loop, state) do
    iTOW = Telemetry.Ublox.get_itow()
    #pvat
    position = state.position
    velocity = state.velocity
    attitude = state.attitude
    unless (Enum.empty?(position) or Enum.empty?(velocity) or Enum.empty?(attitude)) do
      values = [iTOW, position.latitude, position.longitude, position.altitude, position.agl, velocity.speed, velocity.course, attitude.roll, attitude.pitch, attitude.yaw]
      # Logger.info("send pvat message")
      construct_and_send_message({:telemetry, :pvat}, values, state.uart_ref)
    end
    #tx_goals
    level_1 = state.level_1
    level_2 = state.level_2
    level_3 = state.level_3
    unless(Enum.empty?(level_1)) do
      values = [iTOW, level_1.rollrate, level_1.pitchrate, level_1.yawrate, level_1.thrust]
      construct_and_send_message({:tx_goals, 1}, values, state.uart_ref)
    end
    unless(Enum.empty?(level_2)) do
      values = [iTOW, level_2.roll, level_2.pitch, level_2.yaw, level_2.thrust]
      construct_and_send_message({:tx_goals, 2}, values, state.uart_ref)
    end
    unless(Enum.empty?(level_3)) do
      course = Map.get(level_3, :course_flight, Map.get(level_3, :course_ground))
      values = [iTOW, level_3.speed, course, level_3.altitude]
      construct_and_send_message({:tx_goals, 3}, values, state.uart_ref)
    end
    control_state = state.control_state
    unless is_nil(control_state) do
      values = [iTOW, control_state]
      construct_and_send_message(:control_state, values, state.uart_ref)
    end
    {:noreply, state}
  end

  @spec parse(struct(), list()) :: tuple()
  def parse(ublox, buffer) do
    {[byte], buffer} = Enum.split(buffer,1)
    ublox = Telemetry.Ublox.parse(ublox, byte)
    ublox =
    if ublox.payload_ready == true do
      # Logger.warn("ready")
      {msg_class, msg_id} = Telemetry.Ublox.msg_class_and_id(ublox)
      dispatch_message(msg_class, msg_id, Telemetry.Ublox.payload(ublox))
      Telemetry.Ublox.clear(ublox)
    else
      ublox
    end
    if (Enum.empty?(buffer)) do
      ublox
    else
      parse(ublox, buffer)
    end
  end

  @spec dispatch_message(integer(), integer(), list()) :: atom()
  def dispatch_message(msg_class, msg_id, buffer) do
    # Logger.info("Rx'd msg: #{msg_class}/#{msg_id}")
    # Logger.debug("payload: #{inspect(buffer)}")
    case msg_class do
      1 ->
        case msg_id do
          0x69 ->
            [_itow, _nano, ax, ay, az, gx, gy, gz] = Telemetry.Ublox.deconstruct_message(:accel_gyro, buffer)
            # Logger.info("accel xyz: #{ax}/#{ay}/#{az}")
            # Logger.info("gyro xyz: #{gx}/#{gy}/#{gz}")
            store_data(%{accel: %{x: ax, y: ay, z: az}, bodyrate: %{roll: gx, pitch: gy, yaw: gz}})
          _other -> Logger.warn("Bad message id: #{msg_id}")
        end
      0x45 ->
        case msg_id do
          0x00 ->
            msg_type = {:telemetry, :pvat}
            [itow, lat, lon, alt, agl, speed, course, roll, pitch, yaw] = Telemetry.Ublox.deconstruct_message(msg_type, buffer)
            position = %{latitude: lat, longitude: lon, altitude: alt, agl: agl}
            velocity = %{speed: speed, course: course}
            attitude = %{roll: roll, pitch: pitch, yaw: yaw}
            # Logger.debug("roll: #{Common.Utils.eftb_deg(roll,2)}")
            # Logger.debug("agl: #{agl}")
            send_local({msg_type, position, velocity, attitude})
          0x11 ->
            msg_type = {:tx_goals, 1}
            [itow, rollrate, pitchrate, yawrate, thrust] = Telemetry.Ublox.deconstruct_message(msg_type, buffer)
            level_1 = %{rollrate: rollrate, pitchrate: pitchrate, yawrate: yawrate, thrust: thrust}
            send_local({msg_type, level_1}, :tx_goals)
          0x12 ->
            msg_type = {:tx_goals, 2}
            [itow, roll, pitch, yaw, thrust] = Telemetry.Ublox.deconstruct_message(msg_type, buffer)
            level_2 = %{roll: roll, pitch: pitch, yaw: yaw, thrust: thrust}
            send_local({msg_type, level_2}, :tx_goals)
          0x13 ->
            msg_type = {:tx_goals, 3}
            [itow, speed, course, altitude] = Telemetry.Ublox.deconstruct_message(msg_type, buffer)
            level_3 = %{speed: speed, course: course, altitude: altitude}
            send_local({msg_type, level_3}, :tx_goals)
          0x14 ->
            msg_type = :control_state
            [itow, control_state] = Telemetry.Ublox.deconstruct_message(msg_type, buffer)
            send_local({msg_type, control_state})
          _other ->  Logger.warn("Bad message id: #{msg_id}")
        end
      _other ->  Logger.warn("Bad message class: #{msg_class}")
    end
  end

  @spec store_data(map()) :: atom()
  def store_data(data_map) do
    GenServer.cast(__MODULE__, {:store_data, data_map})
  end

  def get_accel_gyro() do
    GenServer.call(__MODULE__, {:get_values, [:accel, :bodyrate]})
  end

  def send_local(message, group) do
    Comms.Operator.send_local_msg_to_group(__MODULE__, message, group, self())
  end

  def send_local(message) do
    Comms.Operator.send_local_msg_to_group(__MODULE__, message, elem(message,0), self())
  end

  @spec construct_and_send_message(any(), list(), any()) :: atom()
  def construct_and_send_message(msg_type, payload, uart_ref) do
    msg = Telemetry.Ublox.construct_message(msg_type, payload)
    Circuits.UART.write(uart_ref, msg)
    Circuits.UART.drain(uart_ref)
  end

  @spec send_message(binary()) :: atom()
  def send_message(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end
end
