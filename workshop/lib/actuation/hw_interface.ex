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
        actuator_driver: config.actuator_driver,
        interface_ref: nil,
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Logger.debug("Begin ActuatorInterfaceOutput")
    interface_ref =
      case state.actuator_driver do
        :pololu ->
          Peripherals.Uart.PololuServo.open_port()
      end
    # unless uart_ref == nil do
    #   actuators_ready()
    # end
    {:noreply, %{state | interface_ref: interface_ref}}
  end

  @impl GenServer
  def handle_cast({:set_actuator_output, actuator, output}, state) do
    pulse_width_ms = get_pw_for_actuator_and_output(state.actuator_driver, actuator, output)
    case state.interface_ref do
      nil -> Logger.debug("No actuator interface for pw: #{pulse_width_ms}")
      interface_ref -> 
        send_pw_to_actuator(state.actuator_driver, interface_ref, actuator.channel_number, pulse_width_ms)
    end
  end

  def set_actuator_output(actuator, output) do
    GenServer.cast(__MODULE__, {:set_actuator_output, actuator, output})
  end

  def get_pw_for_actuator_and_output(actuator_driver, actuator, output) do
    case actuator_driver do
      :pololu ->
        Peripherals.Uart.PololuServo.output_to_ms(output, actuator.reversed, actuator.min_pw_ms, actuator.max_pw_ms)
        # Logger.debug("channel/number/output/ms: #{channel}/#{channel_number}/#{output}/#{inspect(pwm_ms)}")
    end
  end

  def send_pw_to_actuator(actuator_driver, interface_ref, channel_number, pulse_width_ms) do
    case actuator_driver do
      :pololu ->
        Peripherals.Uart.PololuServo.write_microseconds(interface_ref, channel_number, pulse_width_ms)
    end
  end

  defp begin() do
    GenServer.cast(__MODULE__, :begin)
  end



end
