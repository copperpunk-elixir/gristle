defmodule Peripherals.Gpio.Logging.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.start("Start Gpio.Logging.Operator")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    initial_value = Keyword.get(config, :initial_value, 0)
    pin_number = Keyword.fetch!(config, :pin_number)
    pin_direction = Keyword.fetch!(config, :pin_direction)
    pull_mode = Keyword.fetch!(config, :pull_mode)

    options =
      case pin_direction do
        :output -> [initial_value: initial_value]
        :input -> [pull_mode: pull_mode]
      end
    {:ok, ref} = Circuits.GPIO.open(pin_number, pin_direction, options)
    Process.sleep(100)
    if pin_direction == :input do
      Circuits.GPIO.set_interrupts(ref, :both,[suppress_glitches: true])
    end
    state = %{
      gpio_ref: ref,
      time_threshold_cycle_mount_ms: Keyword.fetch!(config, :time_threshold_cycle_mount_ms),
      time_threshold_power_off_ms: Keyword.fetch!(config, :time_threshold_power_off_ms),
    }

    {:noreply, state}
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
