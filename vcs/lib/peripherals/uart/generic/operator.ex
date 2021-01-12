defmodule Peripherals.Uart.Generic.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Uart.Generic.Operator GenServer")
    Logger.info("config: #{inspect(config)}")
    name = via_tuple(Keyword.fetch!(config, :uart_port))
    Logger.warn("Generic.Operator name: #{inspect(name)}")
    config = Keyword.put(config, :name, name)
    Logger.info("new config: #{inspect(config)}")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, name)
    GenServer.cast(name, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Circuits.UART.close(state.uart_ref)
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Logger.warn("generic config begin: #{inspect(config)}")
    name = Keyword.fetch!(config, :name)
    Comms.System.start_operator(name)
    Comms.Operator.join_group(name, :gps_time, self())
    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      name: name,
      uart_ref: uart_ref,
      ublox: Telemetry.Ublox.new(),
      new_values: %{
        attitude_bodyrate: false,
        position_velocity: false,
      },
      clock: Time.Clock.new(),
      publish_id_interval: %{},
      sorter_classification: config[:sorter_classification],
      sorter_time_validity_ms: config[:sorter_time_validity_ms]
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Generic.Operator #{uart_port} setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:gps_time, gps_time}, state) do
    clock = Time.Clock.set_datetime(state.clock, gps_time)
    {:noreply, %{state | clock: clock}}
  end

  @impl GenServer
  def handle_cast({:send_message, message}, state) do
    Circuits.UART.write(state.uart_ref, message)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({{:pv_values, :attitude_bodyrate}, attitude, bodyrate, _dt}, state) do
    new_values = Map.put(state.new_values, :attitude_bodyrate, true)

    state =
      Map.put(state, :attitude, attitude)
      |> Map.put(:bodyrate, bodyrate)
      |> Map.put(:new_values, new_values)

    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({{:pv_values, :position_velocity}, position, velocity, _dt}, state) do
    # Logger.debug("Control rx vel/pos/dt: #{inspect(position)}/#{inspect(velocity)}/#{dt}")
    # Logger.debug("cs: #{state.control_state}")
    new_values = Map.put(state.new_values, :position_velocity, true)
    state =
      Map.put(state, :position, position)
      |> Map.put(:velocity, velocity)
      |> Map.put(:new_values, new_values)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:subscribe, msg_id, interval_ms}, state) do
    Logger.debug("#{inspect(state.name)} pub at #{interval_ms}")
    publish_id_interval = state.publish_id_interval
    publish_interval = Map.get(publish_id_interval, msg_id)
    {timer_name, callback} =
      case msg_id do
        0x00 ->
          if is_nil(publish_interval) do
            Comms.Operator.join_group(state.name, {:pv_values, :position_velocity}, self())
            Comms.Operator.join_group(state.name, {:pv_values, :attitude_bodyrate}, self())
          end
          {:telemetry_pvat_timer, :telemetry_pvat_loop}
      end

    existing_timer = Map.get(state, timer_name)
    timer =
    if is_nil(existing_timer) or (interval_ms != publish_interval) do
      Common.Utils.stop_loop(existing_timer)
      Common.Utils.start_loop(self(), interval_ms, callback)
    else
      existing_timer
    end

    publish_id_interval = Map.put(publish_id_interval, msg_id, interval_ms)
    state =
      Map.put(state, timer_name, timer)
      |> Map.put(:publish_id_interval, publish_id_interval)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")
    ublox = Peripherals.Uart.Generic.parse(state.ublox, :binary.bin_to_list(data), state.name, state.sorter_classification, state.sorter_time_validity_ms)
    {:noreply, %{state | ublox: ublox}}
  end

  @impl GenServer
  def handle_info(:telemetry_pvat_loop, state) do
    new_values = state.new_values
    if new_values.attitude_bodyrate or new_values.position_velocity do
      {now, today} = Time.Server.get_time_day(state.clock)
      iTOW = Telemetry.Ublox.get_itow(now, today)
      position = state.position
      velocity = state.velocity
      attitude = state.attitude
      values = [iTOW, position.latitude, position.longitude, position.altitude, position.agl, velocity.airspeed, velocity.speed, velocity.course, attitude.roll, attitude.pitch, attitude.yaw]
      Peripherals.Uart.Generic.construct_and_send_message_with_ref({:telemetry, :pvat}, values, state.uart_ref)
    end
    {:noreply, state}
  end

  @spec subscribe_to_msg(integer(), integer(), atom()) :: atom()
  def subscribe_to_msg(msg_id, interval_ms, module) do
    Logger.debug("cast sub: #{inspect(module)}")
    GenServer.cast(module, {:subscribe, msg_id, interval_ms})
  end

  @spec via_tuple(binary()) :: tuple()
  def via_tuple(uart_port) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,uart_port)
  end

end
