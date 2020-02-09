defmodule Actuator.Controller do
  use GenServer

  def start_link(config) do
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: __MODULE__)
    GenServer.cast(__MODULE__, :actuators_not_ready)
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        actuators: config.actuators,
        actuator_driver: config.actuator_driver,
        uart_ref: nil
     }
    }
  end

  @impl GenServer
  def handle_cast(:actuators_not_ready, state) do
    Common.Utils.Comms.dispatch_cast(
      :topic_registry,
      :actuator_status,
      {:actuator_status, :not_ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:actuators_ready, state) do
    Common.Utils.Comms.dispatch_cast(
      :topic_registry,
      :actuator_status,
      {:actuator_status, :ready}
    )
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    uart_ref =
      case state.actuator_driver do
        :pololu ->
          Peripherals.Uart.PololuServo.open_port()
      end
    unless uart_ref == nil do
      GenServer.cast(__MODULE__, :actuators_ready)
    end
    {:noreply, %{state | uart_ref: uart_ref}}
  end

  @impl GenServer
  def handle_cast({:move_actuator, actuator_name, output}, state) do
    # Logger.debug("move_actuator on #{actuator_name} to #{output}")
    actuator = get_in(state, [:actuators, actuator_name])
    channel_number = actuator.channel_number
    pwm_ms =
      case state.actuator_driver do
        :pololu -> Peripherals.Uart.PololuServo.output_to_ms(output, actuator.reversed, actuator.min_pw_ms, actuator.max_pw_ms)
        # Logger.debug("channel/number/output/ms: #{channel}/#{channel_number}/#{output}/#{inspect(pwm_ms)}")
      end
    unless pwm_ms == nil do
      Peripherals.Uart.PololuServo.write_microseconds(state.uart_ref, channel_number, pwm_ms)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_output, actuator_name}, _from, state) do
    actuator = get_in(state, [:actuators, actuator_name])
    channel_number = actuator.channel_number
    output =
      case state.actuator_driver do
        :pololu ->
          Peripherals.Uart.PololuServo.get_output_for_channel_number(state.uart_ref, channel_number)
      end
    {:reply, output, state}
  end

  def move_actuator(actuator_name, output) do
    # Logger.debug("move actuator for #{actuator_name}")
    GenServer.cast(__MODULE__, {:move_actuator, actuator_name, output})
  end

  def get_output_for_actuator(actuator_name) do
    GenServer.call(__MODULE__, {:get_output, actuator_name})
  end
end
