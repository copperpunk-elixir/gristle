defmodule Peripherals.Uart.Telemetry.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Uart.Telemetry.Operator GenServer")
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
    Circuits.UART.close(state.uart_ref)
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Comms.System.start_operator(__MODULE__)

    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      uart_ref: uart_ref,
      ublox: Telemetry.Ublox.new(),
      fast_loop_interval_ms: Keyword.fetch!(config, :fast_loop_interval_ms),
      medium_loop_interval_ms: Keyword.fetch!(config, :medium_loop_interval_ms),
      slow_loop_interval_ms: Keyword.fetch!(config, :slow_loop_interval_ms),
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
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
    # Logger.debug("rx'd data: #{inspect(data)}")
    ublox = Peripherals.Uart.Generic.parse(state.ublox, :binary.bin_to_list(data), __MODULE__)
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
      Peripherals.Uart.Generic.construct_and_send_message_with_ref({:telemetry, :pvat}, values, state.uart_ref)
    end
    #tx_goals
    level_1 = Map.get(state, :level_1, %{})
    level_2 = Map.get(state, :level_2, %{})
    level_3 = Map.get(state, :level_3, %{})
    unless(Enum.empty?(level_1)) do
      values = [iTOW, level_1.rollrate, level_1.pitchrate, level_1.yawrate, level_1.thrust]
      Peripherals.Uart.Generic.construct_and_send_message_with_ref({:tx_goals, 1}, values, state.uart_ref)
    end
    unless(Enum.empty?(level_2)) do
      values = [iTOW, level_2.roll, level_2.pitch, level_2.yaw, level_2.thrust]
      Peripherals.Uart.Generic.construct_and_send_message_with_ref({:tx_goals, 2}, values, state.uart_ref)
    end
    unless(Enum.empty?(level_3)) do
      course = Map.get(level_3, :course_flight, Map.get(level_3, :course_ground))
      values = [iTOW, level_3.speed, course, level_3.altitude]
      Peripherals.Uart.Generic.construct_and_send_message_with_ref({:tx_goals, 3}, values, state.uart_ref)
    end
    control_state = Map.get(state, :control_state, nil)
    unless is_nil(control_state) do
      values = [iTOW, control_state]
      Peripherals.Uart.Generic.construct_and_send_message_with_ref(:control_state, values, state.uart_ref)
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
        Peripherals.Uart.Generic.construct_and_send_message_with_ref(:tx_battery, values, state.uart_ref)
      end
    end)
    # Cluster Status
    cluster_status = Map.get(state, :cluster_status)
    unless is_nil(cluster_status) do
      Peripherals.Uart.Generic.construct_and_send_message_with_ref(:cluster_status, [iTOW,cluster_status], state.uart_ref)
    end
    {:noreply, state}
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

end
