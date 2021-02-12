defmodule Peripherals.Uart.Actuation.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start Uart.Actuation.Operator")
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
    Logger.debug("Actuation module: #{Keyword.fetch!(config, :interface_module)}")
    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      interface_module: Keyword.fetch!(config, :interface_module),
      uart_ref: uart_ref,
      interface: nil,
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    interface = apply(state.interface_module, :new_device, [state.uart_ref])

    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Actuation.Operator setup complete!")

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :update_actuators, self())
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    channels = Enum.reduce(actuators_and_outputs, %{}j fn ({_actuator_name, {actuator, output}}, acc) ->
      Logger.debug("op #{actuator.channel_number}: #{output}")
      pulse_width_us = output_to_us(output, actuator.reversed, actuator.min_pw_us, actuator.max_pw_us)
      Map.put(acc, actuator.channel_number, pulse_width_us)
    end)

    apply(state.interface_module, :write_channels, [state.interface, channels])
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, _data}, state) do
    # Logger.debug("data: #{inspect(data)}")
    {:noreply, state}
  end

  def output_to_us(output, reversed, min_pw_us, max_pw_us) do
    # Output will arrive in range [-1,1]
    cond do
      (output < 0) || (output > 1) -> nil
      reversed -> max_pw_us - output*(max_pw_us - min_pw_us)
      true -> min_pw_us + output*(max_pw_us - min_pw_us)
    end
  end
end
