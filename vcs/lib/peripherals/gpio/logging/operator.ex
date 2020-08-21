defmodule Peripherals.Gpio.Logging.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.debug("Start Logging Gpio Operator")
    initial_value = Map.get(config, :initial_value, 0)
    gpio_config = Map.take(config, [:pin_number, :pin_direction, :pull_mode])
    |> Map.put(:initial_value, initial_value)

    GenServer.cast(__MODULE__, {:begin, gpio_config})
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        gpio_ref: nil,
        # pin_number: config.pin_number,
        # pin_direction: config.pin_direction,
        # pull_mode: config.pull_mode,
        # initial_value: Map.get(config, :initial_value, 0),
        time_threshold_cycle_mount_ms: config.time_threshold_cycle_mount_ms,
        time_threshold_power_off_ms: config.time_threshold_power_off_ms,
#        falling_time: nil,
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, gpio}, state) do
    options =
      case gpio.pin_direction do
        :output -> [initial_value: gpio.initial_value]
        :input -> [pull_mode: gpio.pull_mode]
      end
    {:ok, ref} = Circuits.GPIO.open(gpio.pin_number, gpio.pin_direction, options)
    Process.sleep(100)
    if gpio.pin_direction == :input do
      Circuits.GPIO.set_interrupts(ref, :both,[suppress_glitches: true])
    end
    {:noreply, %{state | gpio_ref: ref}}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, _pin_number, timestamp, value}, state) do
    falling_time = if (value == 0), do: timestamp, else: Map.get(state, :falling_time, timestamp)
    if (value == 1) do
      dt = round((timestamp - falling_time)*(1.0e-6))
      if (dt > 0) do
        Logger.debug("dt: #{dt}")
        cond do
          dt > state.time_threshold_power_off_ms ->
            Logger.warn("Power off!")
            Common.Utils.power_off()
          dt > state.time_threshold_cycle_mount_ms ->
            Logger.warn("Cycle USB mount")
            Common.Utils.File.cycle_mount()
          true -> nil
        end
      end
    end
    {:noreply, Map.put(state, :falling_time, falling_time)}
  end
end
