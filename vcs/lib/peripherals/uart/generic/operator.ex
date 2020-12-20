defmodule Peripherals.Uart.Generic.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.info("Start Uart.Generic.Operator GenServer")
    name = via_tuple(Keyword.fetch!(config, :uart_port))
    config = Keyword.put(config, :name, name)
    Logger.info("Generic.Operator name: #{name}")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, name)
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
      name: Keyword.fetch!(config, :name),
      uart_ref: uart_ref,
      ublox: Telemetry.Ublox.new()
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Generic.Operator #{uart_port} setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")
    ublox = Peripherals.Uart.Generic.parse(state.ublox, :binary.bin_to_list(data), state.name)
    {:noreply, %{state | ublox: ublox}}
  end

  @spec via_tuple(binary()) :: tuple()
  def via_tuple(uart_port) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,uart_port)
  end

end
