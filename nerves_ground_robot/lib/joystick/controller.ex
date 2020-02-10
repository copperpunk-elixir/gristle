defmodule Joystick.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start JoystickController")
    joystick_name = Map.get(config, :name, __MODULE__)
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: via_tuple(joystick_name))
    begin(joystick_name)
    start_joystick_loop(joystick_name)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        joystick_driver_config: config.joystick_driver_config,
        joystick: nil,
        channels: Map.get(config, :channels, %{}),
        joystick_timer: nil,
        joystick_loop_interval_ms: Map.get(config, :joystick_loop_interval_ms, 0),
        joystick_cmd_header: Map.get(config, :joystick_cmd_header),
        joystick_cmd_classification: Map.get(config, :joystick_cmd_classification),
        joystick_cmd_output: %{},
        send_msg_switch_pin: Map.get(config, :send_msg_switch_pin),
        send_msg_switch_ref: nil
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    joystick =
      case state.joystick_driver_config.driver do
        :adsadc ->
          Peripherals.I2c.Adsadc.new_adsadc(state.joystick_driver_config)
        _ -> nil
      end

    send_msg_switch_ref =
    if state.send_msg_switch_pin==nil do
      nil
    else
      Peripherals.Gpio.Utils.get_gpio_ref_input_pullup(state.send_msg_switch_pin)
    end
    {:noreply, %{state | joystick: joystick, send_msg_switch_ref: send_msg_switch_ref}, state}
  end

  @impl GenServer
  def handle_cast(:start_joystick_loop, state) do
    state =
      case :timer.send_interval(state.joystick_loop_interval_ms, self(), :joystick_loop) do
        {:ok, joystick_timer} ->
          %{state | joystick_timer: joystick_timer}
        {_, reason} ->
          Logger.debug("Could not start joystick timer: #{inspect(reason)}")
          state
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop_joystick_loop, state) do
    state =
      case :timer.cancel(state.joystick_timer) do
        {:ok, } ->
          %{state | joystick_timer: nil}
        {_, reason} ->
          Logger.debug("Could not stop joystick timer: #{inspect(reason)}")
          state
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_output_for_channel, channel}, _from, state) do
    Logger.info("channel: #{inspect(channel)}")
    Logger.info("output: #{inspect(state.joystick_cmd_output)}")
    output = Map.get(state.joystick_cmd_output, channel.cmd)
    {:reply, output, state}
  end

  @impl GenServer
  def handle_info(:joystick_loop, state) do
    joystick_cmd_output = Enum.reduce(state.channels, state.joystick_cmd_output, fn ({_channel_name, channel}, acc) ->
      case Peripherals.I2c.Adsadc.read_device_channel(state.joystick, channel) do
        {:ok, value} ->
          set_output_for_channel_and_value(channel, value, acc)
        error ->
          Logger.warn("inspect#{error}")
          acc
      end
    end)
    # Send commands
    if (is_switch_on(state.send_msg_switch_ref)) do
      Logger.debug("Joystick: #{inspect(joystick_cmd_output)}")
      Comms.Operator.publish(
        state.joystick_cmd_header.group,
        {
          :topic_registry,
          state.joystick_cmd_header.topic,
          {state.joystick_cmd_header.topic, state.joystick_cmd_classification, joystick_cmd_output}
        })
    end
    {:noreply, %{state | joystick_cmd_output: joystick_cmd_output}}
  end

  def start_joystick_loop(joystick_name \\ __MODULE__) do
    GenServer.cast(via_tuple(joystick_name), :start_joystick_loop)
  end

  def stop_joystick_loop(joystick_name \\ __MODULE__) do
    GenServer.cast(via_tuple(joystick_name), :stop_joystick_loop)
  end

  def begin(joystick_name \\ __MODULE__) do
    GenServer.cast(via_tuple(joystick_name), :begin)
  end

  def set_output_for_channel_and_value(channel, value, joystick_cmd_output \\ %{}) do
    output = calculate_output_for_channel_and_value(channel, value)
    Map.put(joystick_cmd_output, channel.cmd, output)
  end

  def calculate_output_for_channel_and_value(channel, value) do
    channel.multiplier*value
  end

  def get_output_for_joystick_and_channel(joystick_name, channel) do
    GenServer.call(via_tuple(joystick_name), {:get_output_for_channel, channel})
  end

  def is_switch_on(switch_ref) do
    if switch_ref == nil do
      true
    else
      Circuits.GPIO.read(switch_ref) == 0
    end
  end

  
  defp via_tuple(name) do
    Common.ProcessRegistry.via_tuple({__MODULE__, name})
  end
end
