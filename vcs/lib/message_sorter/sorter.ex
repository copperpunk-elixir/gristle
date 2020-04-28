defmodule MessageSorter.Sorter do
  use GenServer
  require Logger

  @default_call_timeout 50

  def start_link(config) do
    Logger.debug("Start MessageSorter: #{inspect(config.name)}")
    Common.Utils.start_link_redudant(GenServer, __MODULE__, config, via_tuple(config.name))
    # GenServer.start_link(__MODULE__, nil, name: via_tuple(name))
  end

  @impl GenServer
  def init(config) do
    {default_message_behavior, default_value} =
      case Map.get(config, :default_message_behavior) do
        nil -> {:default_value, nil}
        :last -> {:last, nil}
        :default_value -> {:default_value, config.default_value}
        :decay -> {:decay, config.decay_value}
      end
    {:ok, %{
        messages: [],
        last_value: Map.get(config, :initial_value, nil),
        default_message_behavior: default_message_behavior,
        default_value: default_value
     }}
  end

  @impl GenServer
  def handle_cast({:add_message, classification, expiration_mono_ms, value}, state) do
    # Logger.debug("add_message: #{inspect(self())}")
    # Check if message has a valid classification
    messages =
    if Enum.empty?(state.messages) || is_valid_classification?(Enum.at(state.messages,0).classification, classification) do
      # Remove any messages that have the same classification (there should be at most 1)
      if value == nil do
        state.messages
      else
        unique_msgs = Enum.reject(state.messages, fn msg ->
          msg.classification == classification
        end)
        new_msg = MessageSorter.MsgStruct.create_msg(classification, expiration_mono_ms, value)
        [new_msg | unique_msgs]
      end
    else
      state.messages
    end
    {:noreply, %{state | messages: messages}}
  end

  @impl GenServer
  def handle_cast(:remove_all_messages, state) do
    {:noreply, %{state | messages: []}}
  end

  @impl GenServer
  def handle_call(:get_all_messages, _from, state) do
    messages = prune_old_messages(state.messages)
    {:reply, messages, %{state | messages: messages}}
  end

  @impl GenServer
  def handle_call(:get_message, _from, state) do
    messages = prune_old_messages(state.messages)
    msg = get_most_urgent_msg(messages)
    {:reply, msg, %{state | messages: messages}}
  end

  @impl GenServer
  def handle_call(:get_value, _from, state) do
    messages = prune_old_messages(state.messages)
    msg = get_most_urgent_msg(messages)
    value =
    if msg == nil do
      case state.default_message_behavior do
        :last -> state.last_value
        :default_value -> state.default_value
      end
    else
      msg.value
    end
    {:reply, value, %{state | messages: messages, last_value: value}}
  end

  def add_message(name, classification, time_validity_ms, value) do
    Logger.debug("MSG sorter: #{inspect(name)}. add message: #{inspect(value)}")
    expiration_mono_ms = get_expiration_mono_ms(time_validity_ms)
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.cast(via_tuple(name), {:add_message, classification, expiration_mono_ms, value})
  end

  def add_message(name, msg_struct) do
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.cast(via_tuple(name), {:add_message, msg_struct.classification, msg_struct.expiration_mono_ms, msg_struct.value})
  end

  def get_message(name) do
    Logger.debug("Get message: from #{inspect(name)}")
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.call(via_tuple(name), :get_message, @default_call_timeout)
  end

  def get_all_messages(name) do
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.call(via_tuple(name), :get_all_messages, @default_call_timeout)
  end

  def get_value(name, timeout \\ @default_call_timeout) do
    GenServer.call(via_tuple(name), :get_value, timeout)
  end

  def remove_messages_for_classification(name, classification) do
    Logger.debug("remove messages for #{name}/#{inspect(classification)} not implemented yet")
  end

  def remove_all_messages(name) do
    GenServer.cast(via_tuple(name), :remove_all_messages)
  end

  def is_valid_classification?(current_classification, new_classification) do
    if length(current_classification) == length(new_classification) do
      num_errors = Enum.reduce(0..length(current_classification)-1, 0, fn index, acc ->
        if is_number(Enum.at(current_classification, index)) do
          acc
        else
          acc + 1
        end
      end)
      num_errors == 0
    else
      false
    end
  end

  def get_most_urgent_msg(msgs) do
    # Logger.debug("messages after pruning: #{inspect(valid_msgs)}")
    sorted_msgs = sort_msgs_by_classification(msgs)
    Enum.at(sorted_msgs, 0)
  end

  def prune_old_messages(msgs) do
    current_time_ms = :erlang.monotonic_time(:millisecond)
    Enum.reject(msgs, &(&1.expiration_mono_ms < current_time_ms))
  end

  defp sort_msgs_by_classification(msgs) do
    Enum.sort_by(msgs, &(&1.classification))
  end

  def get_expiration_mono_ms(time_validity_ms) do
    :erlang.monotonic_time(:millisecond) + time_validity_ms
  end

  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__, name)
  end
end
