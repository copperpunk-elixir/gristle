defmodule Workshop.MultipleUarts do
  require Logger
  use GenServer

  @default_baud 115_200
  def start_link(config) do
    Comms.System.start_link([])
    Comms.ProcessRegistry.start_link()
    Process.sleep(200)
    Logger.debug("Start Uart")
    {:ok, process_id} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, via_tuple(config.name))
    GenServer.cast(via_tuple(config.name), :begin)
    {:ok, process_id}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        name: config.name,
        device_description: config.device_description
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(state.name)
    Logger.debug("uart device: #{state.device_description}")
    port = Peripherals.Uart.Utils.get_uart_devices_containing_string(state.device_description)
    Logger.debug("port: #{inspect(port)}")
    case Circuits.UART.open(state.uart_ref, port, [speed: @default_baud, active: true]) do
      {:error, error} ->
        Logger.error("Error opening UART: #{inspect(error)}")
        raise "#{port} is unavailable"
      _success ->
        Logger.debug("UART opened #{port}")
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:write, data}, state) do
    Logger.debug("#{state.name} writing data: #{inspect(data)}")
    Circuits.UART.write(state.uart_ref, data)
    Circuits.UART.drain(state.uart_ref)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, port, data}, state) do
    Logger.debug("#{state.name} rx'd data on port: #{port}: #{inspect(data)}")
    {:noreply, state}
  end

  def write_uart(name, msg) do
    GenServer.cast(via_tuple(name), {:write, msg})
  end

  def get_config_1() do
    %{
      device_description: "USB Serial",
      name: :telemetry
    }
  end

  def get_config_2() do
    %{
      device_description: "FT232R",
      name: :lidar
    }
  end

  @spec via_tuple(atom()) :: tuple()
  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__, name)
  end


end
