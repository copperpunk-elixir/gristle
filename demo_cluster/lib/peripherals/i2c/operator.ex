defmodule Peripherals.I2c.Operator do
  use GenServer
  require Logger
  require Peripherals.I2c.Utils, as: PIU

  @node_mux_healthy 0
  @guardian_mux_healthy 1
  @mux_unhealthy 2

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start I2c.Operator")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    i2c_ref =
      case Circuits.I2C.open("i2c-1") do
        {:ok, ref} -> ref
        _other -> nil
      end
    leds =
      Enum.reduce(Keyword.get(config, :leds, []), %{}, fn ({led_name, address}, acc) ->
        led = Peripherals.I2c.Led.new(i2c_ref, address)
        Map.put(acc, led_name, led)
      end)


    node = Keyword.fetch!(config, :node)
    state = %{
      i2c_ref: i2c_ref,
      leds: leds,
      node: node,
      guardian: Keyword.fetch!(config, :guardian),
      healthy_muxes: [],
      mux_status: nil,
      servo_output_node: nil
    }

    Comms.System.start_operator(__MODULE__)
    Registry.register(MessageSorterRegistry, {:mux_status, :messages}, Keyword.fetch!(config, :mux_status_sorter_interval_ms))
    Registry.register(MessageSorterRegistry, {:servo_output, :value}, Keyword.fetch!(config, :servo_output_sorter_interval_ms))
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :mux_status_loop_interval_ms), :mux_status_loop)
    color = PIU.get_color_for_node_number(node)
    Logger.debug("self_led_node/color: #{node}/#{inspect(color)}")
    Peripherals.I2c.Led.set_color(leds.self, color)

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
  def handle_cast({:message_sorter_value, :servo_output, classification, value, _status}, state) do
    Logger.debug("I2C rx message sorter value: #{inspect(classification)}/#{inspect(value)}")
    servo_output_node = if is_nil(classification), do: nil, else: Enum.at(classification, 1)
    if servo_output_node != state.servo_output_node do
      color = PIU.get_color_for_node_number(servo_output_node)
      Logger.debug("servo_output_led_node/color: #{servo_output_node}/#{inspect(color)}")
      Peripherals.I2c.Led.set_color(state.leds.servo_output, color)
    end
    {:noreply, %{state | servo_output_node: servo_output_node}}
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
      mux_led_node =
        case mux_status do
          @node_mux_healthy -> state.node
          @guardian_mux_healthy -> state.guardian
          _unhealthy -> nil
        end

      color = PIU.get_color_for_node_number(mux_led_node)
      Logger.debug("mux_led_node/color: #{mux_led_node}/#{inspect(color)}")
      Peripherals.I2c.Led.set_color(state.leds.mux, color)
    end
    {:noreply, %{state | mux_status: mux_status}}
  end
end
