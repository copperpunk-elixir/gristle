defmodule Telemetry.Operator do
  use GenServer
  require Logger

  @default_baud 115_200

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
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    ublox = parse(state.ublox, :binary.bin_to_list(data))
    {:noreply, %{state | ublox: ublox}}
  end

  @spec parse(struct(), list()) :: tuple()
  def parse(ublox, buffer) do
    {[byte], buffer} = Enum.split(buffer,1)
    ublox = Telemetry.Ublox.parse(ublox, byte)
    if ublox.payload_ready == true do
      {msg_class, msg_id} = Telemetry.Ublox.msg_class_and_id(ublox)
      dispatch_message(msg_class, msg_id, Telemetry.Ublox.payload(ublox))
    end
    if (Enum.empty?(buffer)) do
      ublox
    else
      parse(ublox, buffer)
    end
  end

  @spec dispatch_message(integer(), integer(), list()) :: atom()
  def dispatch_message(msg_class, msg_id, buffer) do
    Logger.info("Rx'd msg: #{msg_class}/#{msg_id}")
    Logger.debug("payload: #{inspect(buffer)}")
    case msg_class do
      1 ->
        case msg_id do
          0x69 ->
            bytes = [-4,-4,4,4,4,4,4,4]
            [itow, nano, ax, ay, az, gx, gy, gz] = Telemetry.Ublox.deconstruct_message(buffer,bytes)
            Logger.info("accel xyz: #{ax}/#{ay}/#{az}")
            Logger.info("gyro xyz: #{gx}/#{gy}/#{gz}")
          _other -> Logger.warn("Bad message id: #{msg_id}")
        end
      0x45 ->
        case msg_id do
          0x01 ->
            bytes = [-4,4,4,4,4,4,4,4,4,4]
            [itow, lat, lon, alt, agl, speed, course, roll, pitch, yaw] = Telemetry.Ublox.deconstruct_message(buffer, bytes)
            position = %{latitude: lat, longitude: lon, altitude: alt, agl: agl}
            velocity = %{speed: speed, course: course}
            attitude = %{roll: roll, pitch: pitch, yaw: yaw}
            Logger.debug("agl: #{agl}")
            Logger.debug("yaw: #{yaw*57.3}")
            send_local({{:telemetry, :pvat}, position, velocity, attitude, itow})
          _other ->  Logger.warn("Bad message id: #{msg_id}")
        end
      _other ->  Logger.warn("Bad message class: #{msg_class}")
    end
  end

  def get_accel_gyro() do
    GenServer.call(__MODULE__, :get_accel_gyro)
  end

  def send_local(message) do
    Comms.Operator.send_local_msg_to_group(__MODULE__, message, elem(message,0), self())
  end
end
