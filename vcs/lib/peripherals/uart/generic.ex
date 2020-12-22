defmodule Peripherals.Uart.Generic do
  require Logger

  @spec parse(struct(), list(), atom()) :: struct()
  def parse(ublox, buffer, module) do
    {[byte], buffer} = Enum.split(buffer,1)
    ublox = Telemetry.Ublox.parse(ublox, byte)
    ublox =
    if ublox.payload_ready == true do
      # Logger.debug("ready")
      {msg_class, msg_id} = Telemetry.Ublox.msg_class_and_id(ublox)
      dispatch_message(msg_class, msg_id, Telemetry.Ublox.payload(ublox), module)
      Telemetry.Ublox.clear(ublox)
    else
      ublox
    end
    if (Enum.empty?(buffer)) do
      ublox
    else
      parse(ublox, buffer, module)
    end
  end

  @spec dispatch_message(integer(), integer(), list(), atom()) :: atom()
  def dispatch_message(msg_class, msg_id, payload, module) do
    # Logger.debug("Rx'd msg: #{msg_class}/#{msg_id}")
    # Logger.debug("payload: #{inspect(payload)}")
    case msg_class do
      1 ->
        case msg_id do
          0x69 ->
            [_itow, _nano, ax, ay, az, gx, gy, gz] = Telemetry.Ublox.deconstruct_message(:accel_gyro, payload)
            # Logger.debug("accel xyz: #{ax}/#{ay}/#{az}")
            # Logger.debug("gyro xyz: #{gx}/#{gy}/#{gz}")
            Peripherals.Uart.Telemetry.Operator.store_data(%{accel: %{x: ax, y: ay, z: az}, bodyrate: %{roll: gx, pitch: gy, yaw: gz}})
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
            send_global({{:telemetry, :pvat}, position, velocity, attitude}, module)
          0x11 ->
            msg_type = {:tx_goals, 1}
            [itow, rollrate, pitchrate, yawrate, thrust] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            goals = %{rollrate: rollrate, pitchrate: pitchrate, yawrate: yawrate, thrust: thrust}
            send_global_with_group(:tx_goals, {{:tx_goals, 1}, goals}, module)
          0x12 ->
            msg_type = {:tx_goals, 2}
            [itow, roll, pitch, yaw, thrust] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            goals = %{roll: roll, pitch: pitch, yaw: yaw, thrust: thrust}
            send_global_with_group(:tx_goals, {{:tx_goals, 2}, goals}, module)
          0x13 ->
            msg_type = {:tx_goals, 3}
            [itow, speed, course, altitude] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            goals = %{speed: speed, course: course, altitude: altitude}
            send_global_with_group(:tx_goals, {{:tx_goals, 3}, goals}, module)
          0x14 ->
            msg_type = :control_state
            [itow, control_state] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({:control_state, control_state}, module)
          0x15 ->
            msg_type = :tx_battery
            [itow, battery_id, voltage, current, energy_discharged] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            # Logger.debug("battery #{battery_id} msg rx'd")
            send_global({:tx_battery, battery_id, voltage, current, energy_discharged}, module)
          0x16 ->
            msg_type = :cluster_status
            [itow, cluster_status] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            # cluster_healthy = if (cluster_healthy_base2 == 1), do: true, else: false
            send_global({:cluster_status, cluster_status}, module)
          _other ->  Logger.warn("Bad message id: #{msg_id}")
        end
      0x46 ->
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
            construct_and_send_proto_message(:get_pid_gain, msg, module)
          0x02 ->
            # Msgpax
            msg_type = :get_pid_gain
            [process_variable, output_variable, parameter, value] = Pids.Msgpax.Utils.unpack(msg_type, payload)
            Logger.warn("#{process_variable}-#{output_variable} #{parameter} = #{value}")
          _other -> Logger.warn("Bad message id: #{msg_id}")
        end
      0x50 ->
        # Proto messages
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
            # Protobuf mission
            Logger.debug("proto mission received!")
            msg_type = :mission_proto
            mission_pb = Navigation.Path.Protobuf.Utils.decode_mission(payload)
            mission = Navigation.Path.Protobuf.Utils.new_mission(mission_pb)
            if mission_pb.display do
              send_global({:display_mission, mission}, module)
            else
              send_global({:load_mission, mission, mission_pb.confirm}, module)
            end
          0x02 ->
            msg_type = :clear_mission
            Logger.debug("Clear mission")
            [iTOW] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({:clear_mission, iTOW}, module)
          0x03 ->
            # msg_type = :save_log_proto
            Logger.debug("save log proto received")
            save_log_pb = Display.Scenic.Gcs.Protobuf.SaveLog.decode(:binary.list_to_bin(payload))
            filename =  save_log_pb.filename
            # Logging.Logger.save_log(filename)
            send_global({:save_log, filename}, module)
        end
      0x51 ->
        # Confirmation messages
        case msg_id do
          0x00 ->
            Logger.debug("orbit confirmation received")
            msg_type = :orbit_confirmation
            [radius, latitude, longitude, altitude] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({:display_orbit, radius, latitude, longitude, altitude}, module)
        end
      0x52 ->
        # Peripheral/GCS commands
        case msg_id do
          0x00 ->
            Logger.debug("op rx: orbit")
            Logger.debug("from #{inspect(module)}")
            msg_type = :orbit_inline
            [radius, confirmation] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({:load_orbit, :inline, nil, radius, confirmation>0}, module)
          0x01 ->
            Logger.debug("op rx: orbit centered")
            msg_type = :orbit_centered
            [radius, confirmation] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({:load_orbit, :centered, nil, radius, confirmation>0}, module)
          0x02 ->
            Logger.debug("op rx: orbit at location")
            msg_type = :orbit_at_location
            [radius, latitude, longitude, altitude, confirmation] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            position = Common.Utils.LatLonAlt.new(latitude, longitude, altitude)
            send_global({:load_orbit, :centered, position, radius, confirmation>0}, module)

          0x03 ->
            Logger.debug("op rx: clear orbit")
            msg_type = :clear_orbit
            [confirmation] = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            send_global({:clear_orbit, confirmation>0}, module)
        end
      _other -> Logger.warn("Bad message class: #{msg_class}")
    end
  end

  @spec send_global_with_group(any(), binary(), any()) :: atom()
  def send_global_with_group(group, message, module) do
    Comms.Operator.send_global_msg_to_group(module, message, group, self())
  end

  @spec send_global(binary(), atom()) :: atom()
  def send_global(message, module) do
    # Logger.debug("send global from #{module} to #{inspect(elem(message,0))}")
    Comms.Operator.send_global_msg_to_group(module, message, elem(message,0), self())
  end

  @spec construct_and_send_message_with_ref(any(), list(), any()) :: atom()
  def construct_and_send_message_with_ref(msg_type, payload, uart_ref) do
    # Logger.debug("#{inspect(msg_type)}: #{inspect(payload)}")
    payload = Common.Utils.assert_list(payload)
    msg = Telemetry.Ublox.construct_message(msg_type, payload)
    Circuits.UART.write(uart_ref, msg)
#    Circuits.UART.drain(uart_ref)
  end

  @spec construct_and_send_message(any(), list(), atom()) :: atom()
  def construct_and_send_message(msg_type, payload, module) do
    Logger.debug("#{inspect(msg_type)}: #{inspect(payload)}")
    payload = Common.Utils.assert_list(payload)
    msg = Telemetry.Ublox.construct_message(msg_type, payload)
    send_message(msg, module)
  end

  @spec construct_and_send_proto_message(any(), binary(), atom()) :: atom()
  def construct_and_send_proto_message(msg_type, encoded_payload, module) do
    msg = Telemetry.Ublox.construct_proto_message(msg_type, encoded_payload)
    send_message(msg, module)
  end

  @spec send_message(binary(), atom()) :: atom()
  def send_message(message, module) do
    Logger.debug("module: #{inspect(module)}")
    GenServer.cast(module, {:send_message, message})
  end

  @spec send_message_now(any(), binary()) :: atom()
  def send_message_now(uart_ref, message) do
    Circuits.UART.write(uart_ref, message)
  end

  # @spec get_complete_module(atom()) :: atom()
  # def module do
  #   if is_nil(module) do
  #     raise "module cannot be nil"
  #   end
  #   Module.concat(Peripherals.Uart,module)
  #   |> Module.concat(Operator)
  # end
end
