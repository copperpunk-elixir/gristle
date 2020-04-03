defmodule Actuation.HwInterface do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    Logger.debug("Start Actuation HwInterface")
    begin()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        interface_module: get_interface_module(config.interface_driver_name),
        interface: nil,
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    interface = apply(state.interface_module, :new_device, [%{}])
    interface =
      case apply(state.interface_module, :open_port, [interface]) do
        nil -> raise "#{state.interface_module} is unavailable"
        iface -> iface
      end

    {:noreply, %{state | interface: interface}}
  end

  @impl GenServer
  def handle_cast({:set_actuator_output, actuator, output}, state) do
    pulse_width_ms = get_pw_for_actuator_and_output(state.interface_module, actuator, output)
    case state.interface do
      nil -> Logger.debug("No actuator interface for pw: #{pulse_width_ms}")
      interface ->
        send_pw_to_actuator(state.interface_module, interface, actuator.channel_number, pulse_width_ms)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_actuator_output, actuator}, _from, state) do
    output = apply(state.interface_module, :get_output_for_channel_number, [state.interface, actuator.channel_number])
    {:reply, output, state}
  end

  @impl GenServer
  def handle_call(:get_interface, _from, state) do
    {:reply, state.interface, state}
  end

  def set_output_for_actuator(actuator, output) do
    GenServer.cast(__MODULE__, {:set_actuator_output, actuator, output})
  end

  def get_output_for_actuator(actuator) do
    GenServer.call(__MODULE__, {:get_actuator_output, actuator})
  end

  def get_pw_for_actuator_and_output(interface_module, actuator, output) do
    apply(interface_module, :output_to_ms, [output, actuator.reversed, actuator.min_pw_ms, actuator.max_pw_ms])
  end

  def send_pw_to_actuator(interface_module, interface, channel_number, pulse_width_ms) do
    apply(interface_module, :write_microseconds,[interface, channel_number, pulse_width_ms])
  end

  def get_failsafe_pw_for_actuator(actuator) do
    actuator.failsafe_cmd*(actuator.max_pw_ms - actuator.min_pw_ms) + actuator.min_pw_ms
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end

  defp get_interface_module(driver_name) do
    case driver_name do
      :pololu -> Peripherals.Uart.PololuServo
      other ->
        Logger.error("Actuator Interface #{other} not supported")
        nil
    end
  end

  def get_interface() do
    GenServer.call(__MODULE__, :get_interface)
  end

end
