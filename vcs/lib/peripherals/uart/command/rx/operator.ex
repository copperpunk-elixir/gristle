defmodule Peripherals.Uart.Command.Rx.Operator do
  use Bitwise
  use GenServer
  require Logger

  # @default_baud 115_200

  def start_link(config) do
    Logger.debug("Start Uart.Command.Rx.Operator")
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
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin,config}, _state) do
    Comms.System.start_operator(__MODULE__)

    rx_module = Module.concat(Peripherals.Uart.Command.Rx, Keyword.fetch!(config, :rx_module))
    Logger.debug("Rx module: #{rx_module}")
    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      uart_ref: uart_ref,
      remaining_buffer: [],
      channel_values: [],
      rx_module: rx_module,
      rx: apply(rx_module, :new, [])
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Command.Rx setup complete!")
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
      # Logger.debug("channels: #{inspect(channel_values)}")
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
    # rx = Peripherals.Uart.Command.Dsm.parse(dsm, byte)
    rx = apply(rx_module, :parse, [rx, byte])
    if (Enum.empty?(buffer)) do
      rx
    else
      parse(rx_module, rx, buffer)
    end
  end
end
