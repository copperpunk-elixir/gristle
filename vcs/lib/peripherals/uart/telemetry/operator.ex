defmodule Peripherals.Uart.Telemetry.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Uart.Telemetry.Operator GenServer")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        uart_port: config.uart_port,
        port_options: config.port_options,
        ublox: Telemetry.Ublox.new(),
        fast_loop_interval_ms: config.fast_loop_interval_ms,
        medium_loop_interval_ms: config.medium_loop_interval_ms,
        slow_loop_interval_ms: config.slow_loop_interval_ms,
     }}
  end

  @impl GenServer
  def terminate(reason, state) do
    Circuits.UART.close(state.uart_ref)
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    port_options = state.port_options ++ [active: true]
    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref,state.uart_port, port_options)
     # fast_loop_timer = Common.Utils.start_loop(self(), state.fast_loop_interval_ms, :fast_loop)
    # medium_loop_timer = Common.Utils.start_loop(self(), state.medium_loop_interval_ms, :medium_loop)
    Common.Utils.start_loop(self(), state.slow_loop_interval_ms, :slow_loop)
    Logger.debug("Uart.Telemetry.Operator setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:store_data, data_map}, state) do
    # Logger.debug("store: #{inspect(data_map)}")
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
    Logger.debug("rx'd data: #{inspect(data)}")
    ublox = parse(state.ublox, :binary.bin_to_list(data))
    {:noreply, %{state | ublox: ublox}}
  end

  @impl GenServer
  def handle_info(:slow_loop, state) do
    {now, today} = Time.Server.get_time_day()
    iTOW = Telemetry.Ublox.get_itow(now, today)
    #pvat
    position = Map.get(state, :position, %{})
    velocity = Map.get(state, :velocity, %{})
    attitude = Map.get(state, :attitude, %{})
    unless (Enum.empty?(position) or Enum.empty?(velocity) or Enum.empty?(attitude)) do
      values = [iTOW, position.latitude, position.longitude, position.altitude, position.agl, velocity.airspeed, velocity.speed, velocity.course, attitude.roll, attitude.pitch, attitude.yaw]
      # Logger.debug("send pvat message")
      construct_and_send_message({:telemetry, :pvat}, values, state.uart_ref)
    end
    #tx_goals
    level_1 = Map.get(state, :level_1, %{})
    level_2 = Map.get(state, :level_2, %{})
    level_3 = Map.get(state, :level_3, %{})
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
    control_state = Map.get(state, :control_state, nil)
    unless is_nil(control_state) do
      values = [iTOW, control_state+1]
      construct_and_send_message(:control_state, values, state.uart_ref)
    end
    # Power
    batteries = Map.get(state, :batteries, %{})
    Enum.each(batteries, fn {battery_id, battery} ->
      # Logger.debug("telem batt id: #{battery_id}")
      battery_vie = Health.Hardware.Battery.get_vie(battery)
      unless Enum.member?(battery_vie, nil) do
        # battery_id = Health.Hardware.Battery.get_battery_id(battery)
        values = [iTOW, battery_id] ++ battery_vie
        # Logger.debug("values: #{inspect(values)}")
        construct_and_send_message(:tx_battery, values, state.uart_ref)
      end
    end)
    # Cluster Status
    cluster_status = Map.get(state, :cluster_status,0)
    construct_and_send_message(:cluster_status, [iTOW,cluster_status], state.uart_ref)
    {:noreply, state}
  end

  @spec parse(struct(), list()) :: struct()
  def parse(ublox, buffer) do
    {[byte], buffer} = Enum.split(buffer,1)
    ublox = Telemetry.Ublox.parse(ublox, byte)
    ublox =
    if ublox.payload_ready == true do
      # Logger.debug("ready")
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
  def dispatch_message(msg_class, msg_id, payload) do
    # Logger.debug("Rx'd msg: #{msg_class}/#{msg_id}")
    # Logger.debug("payload: #{inspect(payload)}")
    case msg_class do
      1 ->
        case msg_id do
          0x69 ->
            [_itow, _nano, ax, ay, az, gx, gy, gz] = Telemetry.Ublox.deconstruct_message(:accel_gyro, payload)
            # Logger.debug("accel xyz: #{ax}/#{ay}/#{az}")
            # Logger.debug("gyro xyz: #{gx}/#{gy}/#{gz}")
            store_data(%{accel: %{x: ax, y: ay, z: az}, bodyrate: %{roll: gx, pitch: gy, yaw: gz}})
          _other -> Logger.warn("Bad message id: #{msg_id}")
        end
      0x45 ->
        case msg_id do
          0x00 ->
            msg_type = {:telemetry, :pvat}
            [itow, lat, lon, alt, agl, airspeed, speed, course, roll, pitch, yaw] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            position = %{latitude: lat, longitude: lon, altitude: alt, agl: agl}
            velocity = %{airspeed: airspeed, speed: speed, course: course}
            attitude = %{roll: roll, pitch: pitch, yaw: yaw}
            # Logger.debug("roll: #{Common.Utils.eftb_deg(roll,2)}")
            # Logger.debug("agl: #{agl}")
            send_global({msg_type, position, velocity, attitude})
          0x11 ->
            msg_type = {:tx_goals, 1}
            [itow, rollrate, pitchrate, yawrate, thrust] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            level_1 = %{rollrate: rollrate, pitchrate: pitchrate, yawrate: yawrate, thrust: thrust}
            send_global({msg_type, level_1}, :tx_goals)
          0x12 ->
            msg_type = {:tx_goals, 2}
            [itow, roll, pitch, yaw, thrust] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            level_2 = %{roll: roll, pitch: pitch, yaw: yaw, thrust: thrust}
            send_global({msg_type, level_2}, :tx_goals)
          0x13 ->
            msg_type = {:tx_goals, 3}
            [itow, speed, course, altitude] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            level_3 = %{speed: speed, course: course, altitude: altitude}
            send_global({msg_type, level_3}, :tx_goals)
          0x14 ->
            msg_type = :control_state
            [itow, control_state] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({msg_type, control_state-1})
          0x15 ->
            msg_type = :tx_battery
            [itow, battery_id, voltage, current, energy_discharged] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            # Logger.debug("battery #{battery_id} msg rx'd")
            send_global({msg_type, battery_id, voltage, current, energy_discharged})
          0x16 ->
            msg_type = :cluster_status
            [itow, cluster_status] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            # cluster_healthy = if (cluster_healthy_base2 == 1), do: true, else: false
            send_global({msg_type, cluster_status})
          _other ->  Logger.warn("Bad message id: #{msg_id}")
        end
       0x46  ->
        case msg_id do
          0x00 ->
            # Msgpax
            msg_type = :set_pid_gain
            [process_variable, output_variable, parameter, value] = Pids.Msgpax.Utils.unpack(msg_type, payload)
            Pids.Pid.set_parameter(process_variable, output_variable, parameter, value)
          0x01 ->
            # Msgpax
            msg_type = :request_pid_gain
            [process_variable, output_variable, parameter] = Pids.Msgpax.Utils.unpack(msg_type, payload)
            value = Pids.Pid.get_parameter(process_variable, output_variable, parameter)
            msg = [process_variable, output_variable, parameter, value] |> Msgpax.pack!(iodata: false)
            Peripherals.Uart.Telemetry.Operator.construct_and_send_proto_message(:get_pid_gain, msg)
          0x02 ->
            # Msgpax
            msg_type = :get_pid_gain
            [process_variable, output_variable, parameter, value] = Pids.Msgpax.Utils.unpack(msg_type, payload)
          Logger.warn("#{process_variable}->#{output_variable} #{parameter} = #{value}")

          other -> Logger.warn("Bad message id: #{other}")
        end

      0x50 ->
        case msg_id do
          0x00 ->
            msg_type = :rpc
            [cmd, arg] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            case cmd do
              0x01 -> Logging.Logger.save_log()
              0x02 -> Common.Utils.File.unmount_usb_drive()
              _other -> Logger.warn("Bad cmd/arg: #{cmd}/#{arg}")
            end
          0x01 ->
            msg_type = :mission
            Logger.debug("mission received")
            [airport_code, runway_code, model_code, track_code, num_wps, confirmation] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            airport = Navigation.PathPlanner.get_airport(airport_code)
            runway = Navigation.PathPlanner.get_runway(runway_code)
            model = Navigation.PathPlanner.get_model(model_code)
            track= Navigation.PathPlanner.get_track(track_code)
            mission = Navigation.Path.Mission.get_complete_mission(airport, runway, model, track, num_wps)
            send_global({:load_mission, mission})
            if Navigation.PathPlanner.get_confirmation(confirmation) do
              Logger.debug("send confirmation")
              Navigation.PathPlanner.send_path_mission(airport, runway, model, track, num_wps, false)
            else
              Logger.debug("confirmation received")
            end
          0x02 ->
            # Protobuf mission
            Logger.debug("proto mission received!")
            msg_type = :mission_proto
            mission_pb = Navigation.Path.Protobuf.Utils.decode_mission(payload)
            mission = Navigation.Path.Protobuf.Utils.new_mission(mission_pb)
            send_global({:load_mission, mission})
            if mission_pb.confirm do
              Logger.debug("send confirmation")
              pb_encoded = Navigation.Path.Mission.encode(mission, false)
              construct_and_send_proto_message(msg_type, pb_encoded)
            else
              Logger.debug("confirmation received")
            end
          0x03 ->
            msg_type = :clear_mission
            Logger.debug("Clear mission")
            [iTOW] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({msg_type, iTOW})
          0x04 ->
            msg_type = :save_log_proto
            Logger.debug("save log proto received")
            save_log_pb = Display.Scenic.Gcs.Protobuf.SaveLog.decode(:binary.list_to_bin(payload))
            filename =  save_log_pb.filename
            # Logging.Logger.save_log(filename)
            send_global({:save_log, filename})
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

  @spec get_value(list()) :: any()
  def get_value(keys) do
    keys = Common.Utils.assert_list(keys)
    GenServer.call(__MODULE__, {:get_values, keys})
  end

  # def send_local(message, group) do
  #   Comms.Operator.send_local_msg_to_group(__MODULE__, message, group, self())
  # end

  # def send_local(message) do
  #   Comms.Operator.send_local_msg_to_group(__MODULE__, message, elem(message,0), self())
  # end

  def send_global(message, group) do
    Comms.Operator.send_global_msg_to_group(__MODULE__, message, group, self())
  end

  def send_global(message) do
    Comms.Operator.send_global_msg_to_group(__MODULE__, message, elem(message,0), self())
  end

  @spec construct_and_send_message(any(), list(), any()) :: atom()
  def construct_and_send_message(msg_type, payload, uart_ref) do
    payload = Common.Utils.assert_list(payload)
    msg = Telemetry.Ublox.construct_message(msg_type, payload)
    Circuits.UART.write(uart_ref, msg)
#    Circuits.UART.drain(uart_ref)
  end

  @spec construct_and_send_message(any(), list()) :: atom()
  def construct_and_send_message(msg_type, payload) do
    payload = Common.Utils.assert_list(payload)
    msg = Telemetry.Ublox.construct_message(msg_type, payload)
    send_message(msg)
  end

  @spec construct_and_send_proto_message(any(), binary()) :: atom()
  def construct_and_send_proto_message(msg_type, encoded_payload) do
    msg = Telemetry.Ublox.construct_proto_message(msg_type, encoded_payload)
    send_message(msg)
  end

  @spec send_message(binary()) :: atom()
  def send_message(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end

  @spec send_message_now(any(), binary()) :: atom()
  def send_message_now(uart_ref, message) do
    Circuits.UART.write(uart_ref, message)
  end
end
