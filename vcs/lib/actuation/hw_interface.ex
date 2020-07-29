defmodule Actuation.HwInterface do
  use GenServer
  require Logger

@connection_count_max 10

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.debug("Start Actuation HwInterface")
    GenServer.cast(__MODULE__, {:begin, config.driver_config})
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    interface_module =
      case config.interface_driver_name do
        :pololu -> Peripherals.Uart.PololuServo
        :feather -> Peripherals.Uart.FrskyServo
        other ->
          raise "Actuator Interface #{other} not supported"
      end

    {:ok, %{
        interface_module: interface_module,
        interface: nil,
        channels: %{}
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, driver_config}, state) do
    interface = apply(state.interface_module, :new_device, [driver_config])
    interface_function =
      case state.interface_module do
        Peripherals.Uart.PololuServo -> :open_interface_connection
        Peripherals.Uart.FrskyServo -> :get_frsky_uart_ref
      end
    interface = apply(__MODULE__, interface_function, [state.interface_module, interface, 0, @connection_count_max])
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:set_actuator_output, actuator, output}, state) do
    pulse_width_us = output_to_us(output, actuator.reversed, actuator.min_pw_us, actuator.max_pw_us)
    channels = Map.put(state.channels, actuator.channel_number, pulse_width_us)
    {:noreply, %{state | channels: channels}}
  end

  @impl GenServer
  def handle_cast(:update_actuators, state) do
    apply(state.interface_module, :write_channels, [state.interface, state.channels])
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_actuator_output, actuator}, _from, state) do
    output =
      case state.interface do
        nil ->Logger.debug("No actuator interface")
        interface -> apply(state.interface_module, :get_output_for_channel_number, [interface, actuator.channel_number])
      end
    {:reply, output, state}
  end

  def set_output_for_actuator(actuator,_actuator_name, output) do
    GenServer.cast(__MODULE__, {:set_actuator_output, actuator, output})
  end

  def get_output_for_actuator(actuator) do
    GenServer.call(__MODULE__, {:get_actuator_output, actuator})
  end

  def get_failsafe_pw_for_actuator(actuator) do
    actuator.failsafe_cmd*(actuator.max_pw_us - actuator.min_pw_us) + actuator.min_pw_us
  end

  @spec update_actuators() :: atom()
  def update_actuators() do
    GenServer.cast(__MODULE__, :update_actuators)
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

  defp open_interface_connection(interface_module, interface, connection_count, connection_count_max) do
    case apply(interface_module, :open_port, [interface]) do
      nil ->
        if (connection_count < connection_count_max) do
          Logger.warn("#{interface_module} is unavailable. Retrying in 1 second.")
          Process.sleep(1000)
          open_interface_connection(interface_module, interface, connection_count+1, connection_count_max)
        else
          # Check FrSky
          Logger.warn("#{interface_module} could not be reached. Checking for Frsky interface.")
          uart_ref = Peripherals.Uart.FrskyRx.get_uart_ref()
          if is_nil(uart_ref) do
            raise "#{interface_module} is unavailable"
          else
            Logger.debug("Using Frsky interface")
            # Peripherals.Uart.PololuServo.set_interface_ref(interface, uart_ref)
            apply(interface_module, :set_interface_ref, [interface, uart_ref])
          end
        end
      interface -> interface
    end
  end

  @spec get_frsky_uart_ref(atom(), struct(), integer(), integer()) :: struct()
  def get_frsky_uart_ref(interface_module, interface, count, count_max) do
    unless is_nil(GenServer.whereis(Peripherals.Uart.FrskyRx)) do
      case Peripherals.Uart.FrskyRx.get_uart_ref() do
        nil ->
          Logger.warn("FrskyRx uart_ref is nil")
          if (count < count_max) do
            Process.sleep(1000)
            get_frsky_uart_ref(interface_module, interface, count+1, count_max)
          else
            raise "Could not get uart_ref from FrskyRx"
          end
        uart_ref ->
          Logger.warn("Getting uart_ref from FrskyRx")
          apply(interface_module, :set_interface_ref, [interface, uart_ref])
      end
    else
      Logger.warn("Peripherals.Uart.FrskyRx is not running")
      if (count < count_max) do
        Process.sleep(1000)
        get_frsky_uart_ref(interface_module, interface, count+1, count_max)
      else
        raise "Could not get uart_ref from FrskyRx"
      end
    end
  end
end
