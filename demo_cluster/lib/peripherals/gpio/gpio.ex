defmodule Peripherals.Gpio.Operator do
  use GenServer
  require Logger
  require Peripherals.Gpio.Utils

  @node_mux_healthy 0
  @guardian_mux_healthy 1
  @mux_unhealthy 2

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start Gpio.Operator")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    pins_options = Keyword.get(config, :pins, [])
    gpio_refs =
      Enum.reduce(pins_options, %{}, fn ({pin, options}, acc) ->
        if Common.Utils.is_target?() do
          Logger.info("target")
          {:ok, ref} = Circuits.GPIO.open(pin, options[:direction])
          if Keyword.has_key?(options, :pull_mode), do: Circuits.GPIO.set_pull_mode(ref, options[:pull_mode])
          Map.put(acc, pin, ref)
        else
          acc
        end
      end)

    state = %{
      gpio_refs: gpio_refs,
      node: Keyword.fetch!(config, :node),
      guardian: Keyword.fetch!(config, :guardian),
      healthy_muxes: [],
      mux_status: nil,
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :mux_status, self())
    Registry.register(MessageSorterRegistry, {:mux_status, :messages}, Keyword.fetch!(config, :mux_status_sorter_interval_ms))
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :mux_status_loop_interval_ms), :mux_status_loop)

    :erlang.send_after(2000, self(), {:set_gpio_interrupts, pins_options})
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({:mux_status, node, value}, state) do
    if value == 0 do
      Logger.debug("node #{node} mux status: healthy")
      MessageSorter.Sorter.add_message(:mux_status, [1, node], 1_000_0000, node)
    else
      Logger.debug("node #{node} mux status: unhealthy")
      MessageSorter.Sorter.remove_message_for_classification(:mux_status, [1, node])
    end
    {:noreply, state}
  end


  @impl GenServer
  def handle_cast({:message_sorter_messages, :mux_status, all_mux_messages}, state) do
    # Logger.debug("message sorter message: #{inspect(all_node_messages)}")
    # Nodes and Wards stored as key/value pair, i.e., %{node => ward}
    healthy_muxes =
      Enum.map(all_mux_messages, fn message ->
        message.value
      end)
    Logger.debug("healthy muxes: #{inspect(healthy_muxes)}")
    {:noreply, %{state | healthy_muxes: healthy_muxes}}
  end

  @impl GenServer
  def handle_info({:set_gpio_interrupts, pins_options}, state) do
    Logger.warn("set interrupts: #{inspect(pins_options)}")
    Logger.warn("gpio refs: #{inspect(state.gpio_refs)}")
    Enum.each(state.gpio_refs, fn {pin, ref} ->
      options = Map.get(pins_options, pin)
      if Keyword.has_key?(options, :interrupts) do
        Logger.debug("set interrupt #{options[:interrupts]} for pin #{pin}")
        Circuits.GPIO.set_interrupts(ref, options[:interrupts])
      end
    end)
    {:noreply, state}
  end


  @impl GenServer
  def handle_info({:circuits_gpio, pin, time, value}, state) do
    Logger.debug("pin #{pin} switched to #{value} at time: #{time}")
    if pin == Peripherals.Gpio.Utils.mux_status_pin do
      Comms.Operator.send_global_msg_to_group(__MODULE__, {:mux_status, state.node, value}, nil)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:mux_status_loop, state) do
    mux_status = cond do
      Enum.member?(state.healthy_muxes, state.node) -> @node_mux_healthy
      Enum.member?(state.healthy_muxes, state.guardian) -> @guardian_mux_healthy
      true -> @mux_unhealthy
    end
    # Logger.debug("mux status current/new: #{state.mux_status}/#{mux_status}")
    if mux_status != state.mux_status do
      {node_led, guardian_led} =
        case mux_status do
          @node_mux_healthy -> {1, 0}
          @guardian_mux_healthy -> {0, 1}
          _unhealthy -> {0,0}
        end
      Logger.debug("node/guardian led: #{node_led}/#{guardian_led}")
      set_gpio(Map.get(state.gpio_refs, Peripherals.Gpio.Utils.node_led_pin), node_led)
      set_gpio(Map.get(state.gpio_refs, Peripherals.Gpio.Utils.guardian_led_pin), guardian_led)
    end
    {:noreply, %{state | mux_status: mux_status}}
  end

  @impl GenServer
  def handle_call(:get_pid, _from, state) do
    {:reply, self(), state}
  end

  @spec set_pull_mode(any(), atom()) :: atom()
  def set_pull_mode(gpio_ref, pull_mode) do
    if Common.Utils.is_target?() do
      Circuits.GPIO.set_pull_mode(gpio_ref, pull_mode)
    else
      Logger.debug("Mock Set GPIO pull mode: #{pull_mode}")
    end
  end

  @spec set_interrupts(any(), atom()) :: atom()
  def set_interrupts(gpio_ref, interrupts) do
    if Common.Utils.is_target?() do
      Circuits.GPIO.set_interrupts(gpio_ref, interrupts)
    else
      Logger.debug("Mock Set GPIO interrupt: #{interrupts}")
    end
  end

  @spec set_gpio(any(), integer()) :: atom()
  def set_gpio(gpio_ref, output) do
    if Common.Utils.is_target?() do
      Logger.debug("Set GPIO output on pin #{Circuits.GPIO.pin(gpio_ref)} to: #{output}")
      Circuits.GPIO.write(gpio_ref, output)
    else
      Logger.debug("Mock Set GPIO output to: #{output}")
    end
  end

  @spec mock_callback(integer()) :: atom()
  def mock_callback(value) do
    pid = GenServer.call(__MODULE__, :get_pid)
    send(pid, {:circuits_gpio, Peripherals.Gpio.Utils.mux_status_pin, :os.system_time(:millisecond), value})
  end
end
