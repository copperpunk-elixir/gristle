defmodule Peripherals.Gpio.Logging.Operator do
  use GenServer
  require Logger

  @connection_count_max 10

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.debug("Start Logging Gpio Operator")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        gpio_ref: nil,
        pin_number: config.pin_number,
        pin_direction: config.pin_direction,
        pull_mode: config.pull_mode,
        initial_value: Map.get(config, :initial_value, 0),
        time_threshold_cycle_mount_ms: config.time_threshold_cycle_mount_ms,
        time_threshold_power_off_ms: config.time_threshold_power_off_ms,
        falling_time: 0,
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
    options =
      case state.pin_direction do
        :output -> [initial_value: state.initial_value]
        :input -> [pull_mode: state.pull_mode]
      end
    {:ok, ref} = Circuits.GPIO.open(state.pin_number, state.pin_direction, options)
    Process.sleep(100)
    Circuits.GPIO.set_interrupts(ref, :both)
    {:noreply, %{state | gpio_ref: ref}}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, pin_number, timestamp, value}, state) do
    falling_time = if (value == 0), do: timestamp, else: state.falling_time
    if (value == 1) do
      dt = (timestamp - falling_time)*(1.0e-6)
      Logger.debug("dt: #{dt}")
      cond do
        dt > state.time_threshold_power_off_ms -> Logger.warn("Power off!")
        dt > state.time_threshold_cycle_mount_ms -> Logger.warn("Cycle USB mount")
        true -> nil
      end
    end
    {:noreply, %{state | falling_time: falling_time}}
  end
end
