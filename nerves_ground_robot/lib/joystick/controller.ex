defmodule Joystick.Controller do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start JoystickController")
    process_name = Map.get(config, :name, __MODULE__)
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: via_tuple(process_name))
    start_joystick_loop(process_name)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    joystick = Sensors.I2c.Adsadc.new_adsadc(config.joystick_config)
    {:ok, %{
        joystick: joystick,
        channels: Map.get(config, :channels, []),
        joystick_timer: nil,
        joystick_loop_interval_ms: Map.get(config, :joystick_loop_interval_ms, 0),
        joystick_cmd_message: Map.get(config, :joystick_cmd_message, nil),
        joystick_cmd_sorting: Map.get(config, :joystick_cmd_sorting, nil),
        send_msg_switch_ref: Sensors.Gpio.Utils.get_gpio_ref_input_pullup(Map.get(config, :send_msg_switch_pin, nil))
     }}
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
  def handle_info(:joystick_loop, state) do
    if (is_switch_on(state.send_msg_switch_ref)) do
      output_all_channels = Enum.reduce(state.channels, %{}, fn (channel, acc) ->
        case Sensors.I2c.Adsadc.read_channel(state.joystick, channel) do
          {:ok, value} ->
            output = channel.multiplier*value
            Map.put(acc, channel.cmd, output)
          error ->
            Logger.warn("inspect#{error}")
            acc
        end
      end)
      Logger.debug("Joystick: #{inspect(output_all_channels)}")
      Comms.Operator.publish(
        state.joystick_cmd_message.group,
        {
          :topic_registry,
          state.joystick_cmd_message.topic,
          {state.joystick_cmd_message.topic, state.joystick_cmd_sorting, output_all_channels}
        })
    end
    {:noreply, state}
  end

  defp is_switch_on(switch_ref) do
    (Circuits.GPIO.read(switch_ref) == 0)
  end

  def start_joystick_loop(process_name \\ __MODULE__) do
    GenServer.cast(via_tuple(process_name), :start_joystick_loop)
  end

  def stop_joystick_loop(process_name \\ __MODULE__) do
    GenServer.cast(via_tuple(process_name), :stop_joystick_loop)
  end

  defp via_tuple(name) do
    Common.ProcessRegistry.via_tuple({__MODULE__, name})
  end
end
