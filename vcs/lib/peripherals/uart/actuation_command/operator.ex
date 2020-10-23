defmodule Peripherals.Uart.ActuationCommand.Operator do
  use Bitwise
  use GenServer
  require Logger

  # @default_baud 115_200

  def start_link(config) do
    Logger.info("Start Uart.ActuationCommand.Operator GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, config, __MODULE__)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, uart_ref} = Circuits.UART.start_link()
    {:ok, %{
        uart_ref: uart_ref,
        device_description: config.device_description,
        baud: config.baud,
        start_byte_found: false,
        remaining_buffer: [],
        channel_values: [],
        dsm: Peripherals.Uart.Command.Dsm.new(),
        interface: nil,
        interface_module: config.interface_module,
        channels: %{}
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
    interface = apply(state.interface_module, :new_device, [state.uart_ref])
    port_options = [speed: state.baud, active: true]
    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref,state.device_description, port_options)
    Logger.debug("Uart.ActuationCommand setup complete!")
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    channels = Enum.reduce(actuators_and_outputs, state.channels, fn ({_actuator_name, {actuator, output}}, acc) ->
      # Logger.debug("op #{actuator.channel_number}: #{output}")
      pulse_width_us = output_to_us(output, actuator.reversed, actuator.min_pw_us, actuator.max_pw_us)
      Map.put(acc, actuator.channel_number, pulse_width_us)
    end)
    apply(state.interface_module, :write_channels, [state.interface, channels])
    {:noreply, %{state | channels: channels}}
  end

  @impl GenServer
  def handle_info(:publish_rx_output_loop, state) do
    if (state.new_dsm_data_to_publish and !state.frame_lost) do
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, state.channel_values, state.failsafe_active}, :rx_output, self())
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("data: #{inspect(data)}")
    data_list = state.remaining_buffer ++ :binary.bin_to_list(data)
    dsm = parse(state.dsm, data_list)
    {dsm, channel_values} =
    if dsm.payload_ready == true do
      # Logger.debug("ready")
      channel_values = Peripherals.Uart.Command.Dsm.get_channels(dsm)
      # Logger.debug("omap: #{inspect(dsm.channel_map)}")
      # Logger.debug("channels: #{inspect(channel_values)}")
      Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, channel_values, false}, :rx_output, self())
      {Peripherals.Uart.Command.Dsm.clear(dsm), channel_values}
    else
      {dsm, state.channel_values}
    end
    {:noreply, %{state | dsm: dsm, channel_values: channel_values}}
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
  def handle_call(:get_all_channel_values, _from, state) do
    {:reply, state.channel_values, state}
  end

  @spec parse(struct(), list()) :: struct()
  def parse(dsm, buffer) do
    # Logger.debug("buffer/dsm: #{inspect(buffer)}/#{inspect(dsm)}")
    {[byte], buffer} = Enum.split(buffer,1)
    dsm = Peripherals.Uart.Command.Dsm.parse(dsm, byte)
    if (Enum.empty?(buffer)) do
      dsm
    else
      parse(dsm, buffer)
    end
  end

  @spec update_actuators(map()) :: atom()
  def update_actuators(actuators_and_outputs) do
    GenServer.cast(__MODULE__, {:update_actuators, actuators_and_outputs})
  end

  def output_to_us(output, reversed, min_pw_us, max_pw_us) do
    # Output will arrive in range [-1,1]
    if (output < 0) || (output > 1) do
      nil
    else
      # output = 0.5*(output + 1.0)
      case reversed do
        false ->
          min_pw_us + output*(max_pw_us - min_pw_us)
        true ->
          max_pw_us - output*(max_pw_us - min_pw_us)
      end
    end
  end

  def get_value_for_channel(channel) do
    GenServer.call(__MODULE__, {:get_channel_value, channel})
  end

  def get_values_for_all_channels() do
    GenServer.call(__MODULE__, :get_all_channel_values)
  end

  def get_uart_ref() do
    GenServer.call(__MODULE__, :get_uart_ref)
  end
end