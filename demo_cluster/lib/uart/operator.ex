defmodule Uart.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start Uart.Operator")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  # @impl GenServer
  # def terminate(reason, state) do
  #   result = Circuits.UART.close(state.uart_ref)
  #   Logger.debug("Closing UART port with result: #{inspect(result)}")
  #   state
  # end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    {servo_output_classification, servo_output_time_validity_ms} = Configuration.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, :servo_output)

    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      uart_ref: uart_ref,
      write_timeout: 10,
      servo_output: nil,
      servo_output_classification: servo_output_classification,
      servo_output_time_validity_ms: servo_output_time_validity_ms
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Operator setup complete!")

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, {:global_msg_sorter, :servo_output}, self())
    Registry.register(MessageSorterRegistry, {:servo_output, :value}, Keyword.fetch!(config, :servo_output_sorter_interval_ms))
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :servo_loop_interval_ms), :servo_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:write_value, value}, state) do
    # Logger.debug("write value: #{value}")
    Circuits.UART.write(state.uart_ref, <<value>>, state.write_timeout)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:message_sorter_value, :servo_output, value, _status}, state) do
    # Logger.debug("message sorter value: #{value}")
    {:noreply, %{state | servo_output: value}}
  end

  @impl GenServer
  def handle_cast({{:global_msg_sorter, :servo_output}, classification, time_validity_ms, value}, state) do
    # Logger.debug("rx global msg sorter: #{value}")
    MessageSorter.Sorter.add_message(:servo_output, classification, time_validity_ms, value)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:servo_loop, state) do
    servo_output = state.servo_output
    unless is_nil(servo_output) do
      # Logger.debug("write to servo: #{servo_output}")
      Circuits.UART.write(state.uart_ref, <<servo_output>>, state.write_timeout)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    data_list = :binary.bin_to_list(data)
    value = Enum.at(data_list, -1)
    unless is_nil(value) do
      # Logger.debug("new value: #{value}")
      Comms.Operator.send_global_msg_to_group(__MODULE__, {{:global_msg_sorter, :servo_output}, state.servo_output_classification, state.servo_output_time_validity_ms, value}, nil)
    end
    # Logger.debug("data: #{inspect(data)}")
    {:noreply, state}
  end

  def write_value(value) do
    GenServer.cast(__MODULE__, {:write_value, value})
  end
end
