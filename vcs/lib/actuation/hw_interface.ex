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
        other ->
          raise "Actuator Interface #{other} not supported"
      end

    {:ok, %{
        interface_module: interface_module,
        interface: nil
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
    interface_ref = apply(state.interface_module, :new_device, [driver_config])
    interface = open_interface_connection(state.interface_module, interface_ref, 0, @connection_count_max)
    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:set_actuator_output, actuator, output}, state) do
    pulse_width_ms = get_pw_for_actuator_and_output(state.interface_module, actuator, output)
    case state.interface do
      nil -> Logger.debug("No actuator interface for pw: #{pulse_width_ms}")
      interface -> apply(state.interface_module, :write_microseconds,[interface, actuator.channel_number, pulse_width_ms])
    end
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

  def get_pw_for_actuator_and_output(interface_module, actuator, output) do
    apply(interface_module, :output_to_ms, [output, actuator.reversed, actuator.min_pw_ms, actuator.max_pw_ms])
  end

  def get_failsafe_pw_for_actuator(actuator) do
    actuator.failsafe_cmd*(actuator.max_pw_ms - actuator.min_pw_ms) + actuator.min_pw_ms
  end

  def update_actuators() do
    # This is defined only to allow for an abstraction in Actuation.SwInterface
  end

  defp open_interface_connection(interface_module, interface_ref, connection_count, connection_count_max) do
    case apply(interface_module, :open_port, [interface_ref]) do
      nil ->
        if (connection_count < connection_count_max) do
          Logger.warn("#{interface_module} is unavailable. Retrying in 1 second.")
          Process.sleep(1000)
          open_interface_connection(interface_module, interface_ref, connection_count+1, connection_count_max)
        else
          raise "#{interface_module} is unavailable"
        end
      interface -> interface
    end
  end
end
