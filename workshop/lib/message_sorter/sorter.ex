defmodule MessageSorter.Sorter do
  use GenServer
  require Logger

  @default_call_timeout 50

  def start_link(config) do
    Logger.debug("Start MessageSorter: #{inspect(config.name)}")
    name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, config.name)
    GenServer.start_link(__MODULE__, config, name: name_in_registry)
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        messages: %{
          exact: [],
          min: [],
          max: []
        },
        cmd_limit_min: Keyword.get(config, :cmd_limit_min),
        cmd_limit_max: Keyword.get(config, :cmd_limit_max),
        classification: Keyword.get(config, :classification)
     }
    }
  end

  @impl GenServer
  def handle_cast({:add_message, cmd_type_min_max_exact, classification, expiration_mono_ms, value}, state) do
    # Check if message has a valid classification
    state =
    if is_valid_classification?(state.classification, classification) do
      # Remove any messages that have the same classification (there should be at most 1)
      value = verify_message_within_limits(value, state.cmd_limit_min, state.cmd_limit_max)
      if value == nil do
        state
      else
        messages_list = get_in(state.messages, [cmd_type_min_max_exact])
        unique_cmds = Enum.reject(messages_list, fn cmd ->
          cmd.classification == classification
        end)
        new_cmd = MessageSorter.CmdStruct.create_cmd(classification, expiration_mono_ms, value)
        put_in(state, [:messages, cmd_type_min_max_exact], [new_cmd | unique_cmds])
      end
    else
      state
    end
    # new_cmd = %{priority: priority, authority: authority, expiration_mono_ms: expiration_mono_ms, value: value}
    # Logger.debug("new cmd: #{inspect(new_cmd)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_message, cmd_type_min_max_exact}, _from, state) do
    messages_list = get_in(state.messages, [cmd_type_min_max_exact])
    {msg, remaining_valid_messages} = get_most_urgent_and_return_remaining(messages_list)
    {:reply, msg, put_in(state, [:messages, cmd_type_min_max_exact], remaining_valid_messages)}
  end

  def add_message(name, cmd_type_min_max_exact, classification, time_validity_ms, value) do
    expiration_mono_ms = :erlang.monotonic_time(:millisecond) + time_validity_ms
    name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    GenServer.cast(name_in_registry, {:add_message, cmd_type_min_max_exact, classification, expiration_mono_ms, value})
  end

  def get_message(name, failsafe_value) do
    # Logger.debug("Get message: #{inspect(name)}")
    name_in_registry = Comms.ProcessRegistry.via_tuple(__MODULE__, name)
    desired_value =
      case GenServer.call(name_in_registry, {:get_message, :exact}, @default_call_timeout) do
        nil -> failsafe_value
        value -> value
      end
    # Logger.warn("desired: #{desired_value}")

    min_limit =
      case GenServer.call(name_in_registry, {:get_message, :min}, @default_call_timeout) do
        nil -> desired_value
        min_value -> min_value
      end
    # Logger.warn("min_limit: #{min_limit}")

    max_limit =
      case GenServer.call(name_in_registry, {:get_message, :max}, @default_call_timeout) do
        nil -> desired_value
        max_value -> max_value
      end
    # Logger.warn("max_limi: #{max_limit}")

    Common.Utils.Math.constrain(desired_value, min_limit, max_limit)
  end

  def get_message_minimum(name) do
    GenServer.call(Comms.ProcessRegistry.via_tuple(__MODULE__, name), {:get_message, :min}, 50)
  end

  def get_message_maximum(name) do
    GenServer.call(Comms.ProcessRegistry.via_tuple(__MODULE__, name), {:get_message, :max}, 50)
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

  def verify_message_within_limits(cmd_value, cmd_limit_min, cmd_limit_max) do
    unless (cmd_limit_min == nil) or (cmd_limit_max == nil) do
      if (cmd_value < cmd_limit_min) || (cmd_value > cmd_limit_max) do
        nil
      else
        cmd_value
      end
    else
      cmd_value
    end
  end

  def get_most_urgent_and_return_remaining(cmds) do
    cmds = prune_old_messages(cmds)
    # Logger.debug("messages after pruning: #{inspect(cmds)}")
    most_urgent_cmds =
      case length(cmds) do
        0 -> []
        _ -> sort_most_urgent_cmds(cmds, 0)
      end
    if most_urgent_cmds == [] do
      {nil, []}
    else
      cmd_struct = Enum.sort_by(most_urgent_cmds, &(&1.authority)) |> Enum.at(0)
      {cmd_struct.value, cmds}
    end
  end

  def prune_old_messages(cmds) do
    current_time_ms = :erlang.monotonic_time(:millisecond)
    Enum.reject(cmds, &(&1.expiration_mono_ms < current_time_ms))
  end

  @cmd_priority_search_max 1000 # Just to keep this search from looping forever
  defp sort_most_urgent_cmds(cmds, priority) do
    most_urgent = Enum.reject(cmds, &(&1.priority > priority))
    valid_value = Enum.at(most_urgent, 0)
    if (valid_value == nil) do
      if (priority < @cmd_priority_search_max) do
        sort_most_urgent_cmds(cmds, priority+1)
      else
        []
      end
    else
      most_urgent
    end
  end
end
