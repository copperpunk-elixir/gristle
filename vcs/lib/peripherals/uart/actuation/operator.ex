defmodule Peripherals.Uart.Actuation.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.info("Start Uart.Actuation.Operator GenServer")
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, uart_ref} = Circuits.UART.start_link()
    Logger.debug("Actuation module: #{config.interface_module}")
    {:ok, %{
        interface_module: config.interface_module,
        uart_ref: uart_ref,
        uart_port: config.uart_port,
        port_options: config.port_options,
        interface: nil,
        channels: %{}
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    result = Circuits.UART.close(state.uart_ref)
    Logger.debug("Closing UART port with result: #{inspect(result)}")
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    interface = apply(state.interface_module, :new_device, [state.uart_ref])
    options = state.port_options ++ [active: true]
    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, state.uart_port, options)
    Logger.debug("Uart.Actuation.Operator setup complete!")
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    channels = Enum.reduce(actuators_and_outputs, state.channels, fn ({_actuator_name, {actuator, output}}, acc) ->
      Logger.debug("op #{actuator.channel_number}: #{output}")
      pulse_width_us = output_to_us(output, actuator.reversed, actuator.min_pw_us, actuator.max_pw_us)
      Map.put(acc, actuator.channel_number, pulse_width_us)
    end)
    apply(state.interface_module, :write_channels, [state.interface, channels])
    {:noreply, %{state | channels: channels}}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("data: #{inspect(data)}")
    {:noreply, state}
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
end
