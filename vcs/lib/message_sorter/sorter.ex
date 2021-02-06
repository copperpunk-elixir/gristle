defmodule MessageSorter.Sorter do
  use GenServer
  require Logger

  @registry MessageSorterRegistry

  def start_link(config) do
    Logger.debug("Start MessageSorter: #{inspect(config[:name])}")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, via_tuple(config[:name]))
    GenServer.cast(via_tuple(config[:name]), {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    {default_message_behavior, default_value} =
      case Keyword.get(config, :default_message_behavior) do
        :last -> {:last, nil}
        :default_value -> {:default_value, config[:default_value]}
        :decay -> {:decay, config[:decay_value]}
      end

    publish_value_looper =
      case Keyword.get(config, :publish_value_interval_ms) do
        nil -> nil
        interval_ms ->
          Common.Utils.start_loop(self(), interval_ms, {:publish_loop, :value})
          Common.Utils.start_loop(self(), 1000, {:update_subscriber_loop, :value})
          Common.DiscreteLooper.new(interval_ms)
      end

    publish_messages_looper =
      case Keyword.get(config, :publish_messages_interval_ms) do
        nil -> nil
        interval_ms ->
          Common.Utils.start_loop(self(), interval_ms, {:publish_loop, :messages})
          Common.Utils.start_loop(self(), 1000, {:update_subscriber_loop, :messages})
          Common.DiscreteLooper.new(interval_ms)
      end


    state = %{
      name: config[:name],
      messages: [],
      last_value: Keyword.get(config, :initial_value, nil),
      default_message_behavior: default_message_behavior,
      default_value: default_value,
      value_type: Keyword.fetch!(config, :value_type),
      publish_loopers: %{value: publish_value_looper, messages: publish_messages_looper}
    }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:add_message, classification, expiration_mono_ms, value}, state) do
    # Check if message has a valid classification
    messages =
    if Enum.empty?(state.messages) || is_valid_classification?(Enum.at(state.messages,0).classification, classification) do
      # Remove any messages that have the same classification (there should be at most 1)
      if value == nil || !is_valid_type?(value, state.value_type) do
        Logger.error("Sorter #{inspect(state.name)} add message rejected")
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
  def handle_cast({:get_value_async, name, sender_pid}, state) do
    # Logger.warn("get value async: #{inspect(name)}/#{inspect(sender_pid)}")
    {state, value, status} = get_current_value(state)
    GenServer.cast(sender_pid, {:message_sorter_value, name, value, status})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:publish_loop, :value}, state) do
    publish_looper = Common.DiscreteLooper.step(state.publish_loopers.value)

    {state, value, status} = get_current_value(state)
    name = state.name
    Enum.each(Common.DiscreteLooper.get_members_now(publish_looper), fn dest ->
      # Logger.debug("Send #{inspect(value)}/#{status} to #{inspect(dest)}")
      GenServer.cast(dest, {:message_sorter_value, name, value, status})
    end)
    publish_loopers = Map.put(state.publish_loopers, :value, publish_looper)
    {:noreply, %{state | publish_loopers: publish_loopers}}
  end

  @impl GenServer
  def handle_info({:publish_loop, :messages}, state) do
    publish_looper = Common.DiscreteLooper.step(state.publish_loopers.messages)
    messages = get_all_messages(state)
    name = state.name
    Enum.each(Common.DiscreteLooper.get_members_now(publish_looper), fn dest ->
      # Logger.debug("Send #{inspect(value)}/#{status} to #{inspect(dest)}")
      GenServer.cast(dest, {:message_sorter_messages, name, messages})
    end)
    publish_loopers = Map.put(state.publish_loopers, :messages, publish_looper)
    {:noreply, %{state | publish_loopers: publish_loopers}}
  end

  @impl GenServer
  def handle_info({:update_subscriber_loop, sub_type}, state) do
    subs = Registry.lookup(@registry, {state.name, sub_type})
    # Logger.info("subs: #{inspect(subs)}")
    # Logger.debug("sorter update members: #{inspect(state.name)}/#{sub_type}")
    # Logger.debug("pub looper pre: #{inspect(publish_looper)}")
    publish_looper = Common.DiscreteLooper.update_all_members(Map.get(state.publish_loopers, sub_type), subs)
    # Logger.debug("pub looper post: #{inspect(publish_looper)}")
    publish_loopers = Map.put(state.publish_loopers, sub_type, publish_looper)
    {:noreply, %{state | publish_loopers: publish_loopers}}
  end

  @spec get_current_value(map()) :: any()
  def get_current_value(state) do
    messages = prune_old_messages(state.messages)
    msg = get_most_urgent_msg(messages)
    {value, value_status} =
    if msg == nil do
      case state.default_message_behavior do
        :last -> {state.last_value, :last}
        :default_value -> {state.default_value, :default_value}
      end
    else
      {msg.value, :current}
    end
    {%{state | messages: messages, last_value: value}, value, value_status}
  end

  @spec get_all_messages(map()) :: list()
  def get_all_messages(state) do
    prune_old_messages(state.messages)
  end

  def add_message(name, classification, time_validity_ms, value) do
    # Logger.debug("MSG sorter: #{inspect(name)}. add message: #{inspect(value)}")
    expiration_mono_ms = get_expiration_mono_ms(time_validity_ms)
    GenServer.cast(via_tuple(name), {:add_message, classification, expiration_mono_ms, value})
  end

  def add_message(name, msg_struct) do
    GenServer.cast(via_tuple(name), {:add_message, msg_struct.classification, msg_struct.expiration_mono_ms, msg_struct.value})
  end

  @spec get_value_async(any(), any()) :: atom()
  def get_value_async(name, sender_pid) do
    GenServer.cast(via_tuple(name), {:get_value_async, name, sender_pid})
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

  defp is_valid_type?(value, desired_type) do
    case desired_type do
      :number -> is_number(value)
      :map -> is_map(value)
      :atom -> is_atom(value)
      :tuple -> is_tuple(value)
      _other -> false
    end
  end

  def registry() do
    @registry
  end
end
