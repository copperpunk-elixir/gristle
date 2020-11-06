defmodule Peripherals.Uart.Command.Rx.Operator do
  use Bitwise
  use GenServer
  require Logger

  # @default_baud 115_200

  def start_link(config) do
    Logger.info("Start Uart.Command.Rx.Operator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    rx_module = Module.concat(Peripherals.Uart.Command.Rx, config.rx_module)
    Logger.debug("Rx module: #{rx_module}")
    {:ok, %{
        uart_ref: uart_ref,
        device_description: config.device_description,
        port_options: config.port_options,
        remaining_buffer: [],
        channel_values: [],
        rx_module: rx_module,
        rx: apply(rx_module, :new, [])
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
    port_options = state.port_options ++ [active: true]
    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref,state.device_description, port_options)
    Logger.debug("Uart.Command.Rx setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    Logger.debug("data: #{inspect(data)}")
    data_list =
    if is_binary(data) do
      state.remaining_buffer ++ :binary.bin_to_list(data)
    else
      state.remaining_buffer
    end
    rx_module = state.rx_module

    rx =
    if Enum.empty?(data_list) do
      state.rx
    else
      parse(rx_module, state.rx, data_list)
    end

    {rx, channel_values} =
    if rx.payload_ready == true do
      # Logger.debug("ready")
      channel_values = apply(rx_module, :get_channels, [rx])
      # Logger.debug("omap: #{inspect(rx.channel_map)}")
      Logger.debug("channels: #{inspect(channel_values)}")
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, channel_values, false}, :rx_output, self())
      {apply(rx_module, :clear, [rx]), channel_values}
    else
      {rx, state.channel_values}
    end
    {:noreply, %{state | rx: rx, channel_values: channel_values}}
  end

  @impl GenServer
  def handle_call(:get_uart_ref, _from, state) do
    {:reply, state.uart_ref, state}
  end

  @impl GenServer
  def handle_call({:get_channel_value, channel}, _from, state) do
    value = Enum.at(state.channel_values,channel)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call(:get_channel_value, _from, state) do
    {:reply, state.channel_values, state}
  end

  @spec parse(atom(), struct(), list()) :: struct()
  def parse(rx_module, rx, buffer) do
    # Logger.debug("buffer/rx: #{inspect(buffer)}/#{inspect(rx)}")
    {[byte], buffer} = Enum.split(buffer,1)
    # rx = Peripherals.Uart.Command.Dsm.parse(dsm, byte)
    rx = apply(rx_module, :parse, [rx, byte])
    if (Enum.empty?(buffer)) do
      rx
    else
      parse(rx_module, rx, buffer)
    end
  end

  def get_value_for_channel(channel) do
    GenServer.call(__MODULE__, {:get_channel_value, channel})
  end

  def get_values_for_all_channels() do
    GenServer.call(__MODULE__, {:get_all_channel_value})
  end

  def get_uart_ref() do
    GenServer.call(__MODULE__, :get_uart_ref)
  end
end
