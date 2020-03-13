defmodule Joystick.InterfaceInput do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start JoystickInterfaceInput")
    # joystick_name = Map.get(config, :name)
    # process_key = Comms.ProcessRegistry.get_key_for_module_and_name(__MODULE__, joystick_name)
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, joystick_name)
    # config = %{config | process_key: process_key}
    process_registry_id = config.process_registry_id
    {:ok, pid} = GenServer.start_link(__MODULE__, config, name: process_registry_id)
    begin(process_registry_id)
    start_joystick_loop(process_registry_id)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        joystick_driver_config: config.joystick_driver_config,
        joystick: nil,
        channels: Keyword.get(config, :channels, %{}),
        joystick_timer: nil,
        joystick_loop_interval_ms: Keyword.get(config, :joystick_loop_interval_ms, 0),
        send_msg_switch_pin: Keyword.get(config, :send_msg_switch_pin),
        send_msg_switch_ref: nil
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    joystick = state.joystick_driver.new(state.joystick_driver_config)
    send_msg_switch_ref = get_switch_ref(state.send_msg_switch_pin)
    {:noreply, %{state | joystick: joystick, send_msg_switch_ref: send_msg_switch_ref}}
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

  # @impl GenServer
  # def handle_call({:get_output_for_channel, channel}, _from, state) do
  #   Logger.info("channel: #{inspect(channel)}")
  #   Logger.info("output: #{inspect(state.joystick_cmd_output)}")
  #   output = Map.get(state.joystick_cmd_output, channel.cmd)
  #   {:reply, output, state}
  # end

  @impl GenServer
  def handle_info(:joystick_loop, state) do
    joystick_cmd_output = Enum.each(state.channels, fn ({_channel_name, channel}) ->
      case state.joystick_driver.read_device_channel(state.joystick, channel.pin, channel.inverted) do
        {:ok, value} ->
          Joystick.Gsm.update_channel(state.joystick_gsm, channel, value)
          # set_output_for_channel_and_value(channel, value, acc)
        error ->
          Logger.warn("inspect#{error}")
          # acc
      end
    end)
    # Send commands
    Joystick.Gsm.update_switch(is_switch_on(state.send_msg_switch_ref))
    # if (is_switch_on(state.send_msg_switch_ref)) do
    #   Logger.debug("Joystick: #{inspect(joystick_cmd_output)}")
    #   state.joystick_cmd_callback.(joystick_cmd_output)
    #   # Comms.Operator.publish(
    #   #   state.joystick_cmd_header.group,
    #   #   {
    #   #     :topic_registry,
    #   #     state.joystick_cmd_header.topic,
    #   #     {state.joystick_cmd_header.topic, :exact, state.joystick_cmd_classification, joystick_cmd_output}
    #     # })
    # end
    # {:noreply, %{state | joystick_cmd_output: joystick_cmd_output}}
    {:noreply, state}
  end

  def start_joystick_loop(via_tuple) do
    GenServer.cast(via_tuple, :start_joystick_loop)
  end

  def stop_joystick_loop(via_tuple) do
    GenServer.cast(via_tuple, :stop_joystick_loop)
  end

  def begin(via_tuple) do
    GenServer.cast(via_tuple, :begin)
  end

  # def set_output_for_channel_and_value(channel, value, joystick_cmd_output \\ %{}) do
  #   output = calculate_output_for_channel_and_value(channel, value)
  #   Map.put(joystick_cmd_output, channel.cmd, output)
  # end

  def calculate_output_for_channel_and_value(channel, value) do
    channel.multiplier*value
  end

  # def get_output_for_joystick_and_channel(via_tuple, channel) do
  #   GenServer.call(via_tuple, {:get_output_for_channel, channel})
  # end

  def is_switch_on(switch_ref) do
    if switch_ref == nil do
      true
    else
      Circuits.GPIO.read(switch_ref) == 0
    end
  end

  def get_switch_ref(switch_pin) do
    if switch_pin==nil do
      nil
    else
      Peripherals.Gpio.Utils.get_gpio_ref_input_pullup(state.send_msg_switch_pin)
    end
  end
end
