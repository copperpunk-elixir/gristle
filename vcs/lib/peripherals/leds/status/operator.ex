defmodule Peripherals.Leds.Status.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start Leds.Status.Operator")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    state = %{}
    Enum.each(config[:leds], fn led_config ->
      %{:name => name, :on_duration_ms => on, :off_duration_ms => off} = led_config
      blink(name, on, off)
    end)
    {:noreply, state}
  end

  @spec blink(binary(), integer(), integer()) :: atom()
  def blink(led_key, on_duration_ms, off_duration_ms) do
    # Logger.debug "blinking led #{inspect led_key}"
    Nerves.Leds.set([{led_key, true}])
    :timer.sleep(on_duration_ms)
    Nerves.Leds.set([{led_key, false}])
    :timer.sleep(off_duration_ms)
    blink(led_key, on_duration_ms, off_duration_ms)
  end
end
