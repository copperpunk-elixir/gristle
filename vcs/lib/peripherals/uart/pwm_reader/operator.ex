defmodule Peripherals.Uart.PwmReader.Operator do
  use GenServer
  require Logger

  @pwm_min_us 1100
  @pwm_range_us 800


  def start_link(config) do
    Logger.debug("Start PwmReader.Operator")
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
        baud: config.baud,
        ublox: Telemetry.Ublox.new()
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

    Comms.Operator.join_group(__MODULE__, :pwm_input, self())
    Logger.info("pwm_reader device: #{state.device_description}")
    port = Peripherals.Uart.Utils.get_uart_devices_containing_string(state.device_description)
    Logger.info("pwm_Reader port: #{inspect(port)}")
    case Circuits.UART.open(state.uart_ref, port, [speed: state.baud, active: true]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{port} is unavailable"
      _success ->
        Logger.debug("PWM reader opened #{port}")
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.info("rx'd data: #{inspect(data)}")
    ublox = parse(state.ublox, :binary.bin_to_list(data))
    {:noreply, %{state | ublox: ublox}}
  end

  @spec parse(struct(), list()) :: struct()
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
  def dispatch_message(msg_class, msg_id, payload) do
    # Logger.debug("payload: #{inspect(payload)}")
    case msg_class do
      0x51 ->
        case msg_id do
          0x00 ->
            num_chs = round(length(payload)/2)
            # Logger.info("num chs: #{num_chs}")
            msg_type = {:pwm_reader, num_chs}
            all_channels = Telemetry.Ublox.deconstruct_message(msg_type, payload)
            # Logger.info("all: channels: #{inspect(all_channels)}")
            scaled_values = Enum.map(all_channels, fn x ->
              Common.Utils.Math.constrain((x-@pwm_min_us)/@pwm_range_us,0.0, 1.0)
            end)
            Comms.Operator.send_local_msg_to_group(__MODULE__, {:pwm_input, scaled_values},self())
        end
    end
  end

end