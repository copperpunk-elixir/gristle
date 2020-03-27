defmodule MessageSorter.Sorter do
  use GenServer
  require Logger

  @default_call_timeout 50

  def start_link(name) do
    Logger.debug("Start MessageSorter: #{inspect(name)}")
    GenServer.start_link(__MODULE__, nil, name: via_tuple(name))
  end

  @impl GenServer
  def init(_) do
    {:ok, []}
  end

  @impl GenServer
  def handle_cast({:add_message, classification, expiration_mono_ms, value}, stored_messages) do
    # Check if message has a valid classification
    stored_messages =
    if Enum.empty?(stored_messages) || is_valid_classification?(Enum.at(stored_messages,0).classification, classification) do
      # Remove any messages that have the same classification (there should be at most 1)
      if value == nil do
        stored_messages
      else
        unique_msgs = Enum.reject(stored_messages, fn msg ->
          msg.classification == classification
        end)
        new_msg = MessageSorter.MsgStruct.create_msg(classification, expiration_mono_ms, value)
        [new_msg | unique_msgs]
      end
    else
      stored_messages
    end
    {:noreply, stored_messages}
  end

  @impl GenServer
  def handle_cast(:remove_all_messages, _stored_messages) do
    {:noreply, []}
  end

  @impl GenServer
  def handle_call(:get_all_messages, _from, stored_messages) do
    {:reply, prune_old_messages(stored_messages), stored_messages}
  end

  @impl GenServer
  def handle_call(:get_message, _from, stored_messages) do
    valid_messages = prune_old_messages(stored_messages)
    msg = get_most_urgent_msg(valid_messages)
    {:reply, msg, valid_messages}
  end

  @impl GenServer
  def handle_call(:get_value, _from, stored_messages) do
    valid_messages = prune_old_messages(stored_messages)
    msg = get_most_urgent_msg(valid_messages)
    value = get_message_value(msg)
    {:reply, value, valid_messages}
  end

  def add_message(name, classification, time_validity_ms, value) do
    expiration_mono_ms = get_expiration_mono_ms(time_validity_ms)
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.cast(via_tuple(name), {:add_message, classification, expiration_mono_ms, value})
  end

  def add_message(name, msg_struct) do
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.cast(via_tuple(name), {:add_message, msg_struct.classification, msg_struct.expiration_mono_ms, msg_struct.value})
  end

  def get_message(name) do
    # Logger.debug("Get message: #{inspect(process)}")
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.call(via_tuple(name), :get_message, @default_call_timeout)
  end

  def get_all_messages(name) do
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.call(via_tuple(name), :get_all_messages, @default_call_timeout)
  end

  def get_value(name) do
    # name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.call(via_tuple(name), :get_value, @default_call_timeout)
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

  def get_message_value(msg) do
    if msg == nil do
      nil
    else
      msg.value
    end
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
