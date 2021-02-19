defmodule Cluster.Led do
  use GenServer
  require Logger

  @led "led0"

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start Cluster.Led")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    state = %{
      network_status: nil
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :network_status, self())
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :led_loop_interval_ms), :led_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:network_status, status}, state) do
    # Logger.debug("rx new network status: #{inspect(status)}")
    {:noreply, %{state | network_status: status}}
  end

  @impl GenServer
  def handle_info(:led_loop, state) do
    # Logger.debug "blinking led for status #{inspect(state.network_status)}"
    case state.network_status do
      nil -> blink_unknown()
      :searching -> blink_searching()
      :connected -> blink_connected()
      :valid_ip -> blink_valid_ip()
    end
    {:noreply, state}
  end

  @spec blink_unknown() :: atom()
  def blink_unknown() do
    Nerves.Leds.set(@led, true)
    :timer.sleep(900)
    Nerves.Leds.set(@led, false)
  end

  @spec blink_searching() :: atom()
  def blink_searching() do
    Nerves.Leds.set(@led, true)
    :timer.sleep(500)
    Nerves.Leds.set(@led, false)
  end

  @spec blink_connected() :: atom()
  def blink_connected() do
    Nerves.Leds.set(@led, true)
    :timer.sleep(50)
    Nerves.Leds.set(@led, false)
    :timer.sleep(100)
    Nerves.Leds.set(@led, true)
    :timer.sleep(50)
    Nerves.Leds.set(@led, false)
  end

  @spec blink_valid_ip() :: atom()
  def blink_valid_ip() do
    Nerves.Leds.set(@led, true)
    :timer.sleep(100)
    Nerves.Leds.set(@led, false)
  end
end
