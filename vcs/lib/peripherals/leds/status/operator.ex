defmodule Peripherals.Leds.Status.Operator do
  use GenServer
  require Logger

  @on_duration 100
  @off_duration 900

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, config, __MODULE__)
    Logger.info("Start Leds.Status.Operator GenServer")
    GenServer.cast(__MODULE__, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    # Start the low-level actuator driver
    {:ok, %{
        led: config.led
     }
    }
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    blink(state.led)
    {:noreply, state}
  end


  def blink(led_key) do
    # Logger.debug "blinking led #{inspect led_key}"
    Nerves.Leds.set([{led_key, true}])
    :timer.sleep(@on_duration)
    Nerves.Leds.set([{led_key, false}])
    :timer.sleep(@off_duration)
    blink(led_key)
  end
end
