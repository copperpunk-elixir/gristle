defmodule Peripherals.Gpio.Logging.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.info("Start Gpio.Logging.Operator GenServer")
    initial_value = Keyword.get(config, :initial_value, 0)
    gpio_config = Keyword.take(config, [:pin_number, :pin_direction, :pull_mode])
    |> Keyword.put(:initial_value, initial_value)

    GenServer.cast(__MODULE__, {:begin, gpio_config})
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        gpio_ref: nil,
        time_threshold_cycle_mount_ms: Keyword.fetch!(config, :time_threshold_cycle_mount_ms),
        time_threshold_power_off_ms: Keyword.fetch!(config, :time_threshold_power_off_ms),
     }
    }
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, gpio_config}, state) do
    options =
      case gpio_config[:pin_direction] do
        :output -> [initial_value: gpio_config[:initial_value]]
        :input -> [pull_mode: gpio_config[:pull_mode]]
      end
    {:ok, ref} = Circuits.GPIO.open(Keyword.fetch!(gpio_config, :pin_number), Keyword.fetch!(gpio_config, :pin_direction), options)
    Process.sleep(100)
    if gpio_config[:pin_direction] == :input do
      Circuits.GPIO.set_interrupts(ref, :both,[suppress_glitches: true])
    end
    {:noreply, %{state | gpio_ref: ref}}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, _pin_number, timestamp, value}, state) do
    falling_time = if (value == 0), do: timestamp, else: Map.get(state, :falling_time, timestamp)
    if (value == 1) do
      dt = round((timestamp - falling_time)*(1.0e-6))
        Logger.debug("dt: #{dt}")
      if (dt > state.time_threshold_cycle_mount_ms) do
        Logger.debug("Save log")
        Logging.Logger.save_log("GPIO_intentional")
        Logger.debug("Cycle USB mount")
        Common.Utils.File.cycle_mount()
      end
      if (dt > state.time_threshold_power_off_ms) do
        Logger.debug("Power off!")
        Common.Utils.power_off()
      end
    end
    {:noreply, Map.put(state, :falling_time, falling_time)}
  end
end
