defmodule Peripherals.Uart.ActuationCommand.Operator do
  use Bitwise
  use GenServer
  require Logger

  # @default_baud 115_200

  def start_link(config) do
    Logger.debug("Start Uart.ActuationCommand.Operator")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    result = Circuits.UART.close(state.uart_ref)
    Logger.debug("Closing UART port with result: #{inspect(result)}")
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :update_actuators, self())

    rx_module = Module.concat(Peripherals.Uart.Command.Rx, Keyword.fetch!(config, :rx_module))
    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      uart_ref: uart_ref,
      start_byte_found: false,
      remaining_buffer: [],
      channel_values: [],
      rx_module: rx_module,
      rx: apply(rx_module, :new, []),
      interface: nil,
      interface_module: Keyword.fetch!(config, :interface_module),
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    interface = apply(state.interface_module, :new_device, [state.uart_ref])

    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.ActuationCommand setup complete!")
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    channels = Enum.reduce(actuators_and_outputs, %{}, fn ({_actuator_name, {actuator, output}}, acc) ->
     # Logger.debug("op #{actuator.channel_number}: #{output}")
      pulse_width_us = output_to_us(output, actuator.reversed, actuator.min_pw_us, actuator.max_pw_us)
      Map.put(acc, actuator.channel_number, pulse_width_us)
    end)
    # Logger.debug(Common.Utils.eftb_map(channels, 0))
    apply(state.interface_module, :write_channels, [state.interface, channels])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:publish_rx_output_loop, state) do
    if (state.new_rx_data_to_publish and !state.frame_lost) do
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, state.channel_values, state.failsafe_active}, :rx_output, self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
   # Logger.debug("data: #{inspect(data)}")
    data_list =
    if is_binary(data) do
      state.remaining_buffer ++ :binary.bin_to_list(data)
    else
      state.remaining_buffer
    end
#Logger.debug("data_list: #{inspect(data_list)}")
    rx_module = state.rx_module
    rx =
    if Enum.empty?(data_list) do
      state.rx
    else
      parse(rx_module, state.rx, data_list)
    end
    {rx, channel_values} =
    if rx.payload_ready do
      channel_values = apply(rx_module, :get_channels, [rx])
      # Logger.debug("ready")
      # Logger.debug("omap: #{inspect(rx.channel_map)}")
      # Logger.debug("channels: #{inspect(Enum.at(channel_values, 0))}")
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, channel_values, false}, :rx_output, self())
      {apply(rx_module, :clear, [rx]), channel_values}
    else
      {rx, state.channel_values}
    end
    {:noreply, %{state | rx: rx, channel_values: channel_values}}
  end

  @spec parse(atom(), struct(), list()) :: struct()
  def parse(rx_module, rx, buffer) do
    # Logger.debug("buffer/rx: #{inspect(buffer)}/#{inspect(rx)}")
    {[byte], buffer} = Enum.split(buffer,1)
    rx = apply(rx_module, :parse, [rx, byte])
    if Enum.empty?(buffer) do
      rx
    else
      parse(rx_module, rx, buffer)
    end
  end

  # @spec update_actuators(map()) :: atom()
  # def update_actuators(actuators_and_outputs) do
  #   GenServer.cast(__MODULE__, {:update_actuators, actuators_and_outputs})
  # end

  def output_to_us(output, reversed, min_pw_us, max_pw_us) do
    # Output will arrive in range [-1,1]
    cond do
      (output < 0) || (output > 1) -> nil
      reversed -> max_pw_us - output*(max_pw_us - min_pw_us)
      true -> min_pw_us + output*(max_pw_us - min_pw_us)
    end
  end
end
