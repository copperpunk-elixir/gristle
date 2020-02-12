defmodule CommandSorter.Sorter do
  use GenServer
  require Logger

  @default_call_timeout 50

  def start_link(config) do
    Logger.debug("Start CommandSorter: #{inspect(config.name)}")
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        commands: %{
          exact: [],
          min: [],
          max: []
        },
        command_limit_min: config.command_limit_min,
        command_limit_max: config.command_limit_max
     }
    }
  end

  @impl GenServer
  def handle_cast({:add_command, cmd_type_min_max_exact, classification, value}, state) do
    # Remove any commands that have the same priority/authority (there should be at most 1)
    value = verify_command_within_limits(value, state.command_limit_min, state.command_limit_max)
    state =
    if value == nil do
      state
    else
      commands_list = get_in(state.commands, [cmd_type_min_max_exact])
      unique_cmds = Enum.reject(commands_list, fn cmd ->
        (cmd.priority==classification.priority) && (cmd.authority==classification.authority)
      end)
      new_cmd = CommandSorter.CmdStruct.create_cmd(classification, value)
      put_in(state, [:commands, cmd_type_min_max_exact], [new_cmd | unique_cmds])
    end
    # new_cmd = %{priority: priority, authority: authority, expiration_mono_ms: expiration_mono_ms, value: value}
    # Logger.debug("new cmd: #{inspect(new_cmd)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_command, cmd_type_min_max_exact}, _from, state) do
    # Logger.debug("Available commands: #{inspect(state.commands)}")
    commands_list = get_in(state.commands, [cmd_type_min_max_exact])
    {cmd, remaining_valid_commands} = get_most_urgent_and_return_remaining(commands_list)
    # Logger.debug("Most urgent cmd: #{inspect(cmd)}")
    {:reply, cmd, put_in(state, [:commands, cmd_type_min_max_exact], remaining_valid_commands)}
  end

  def add_command(name, cmd_type_min_max_exact, classification, value) do
    expiration_mono_ms = :erlang.monotonic_time(:millisecond) + classification.time_validity_ms
    GenServer.cast(via_tuple(name), {:add_command, cmd_type_min_max_exact, Map.put(classification,:expiration_mono_ms, expiration_mono_ms), value})
  end

  def get_command(name, failsafe_value) do
    desired_value =
      case GenServer.call(via_tuple(name), {:get_command, :exact}, @default_call_timeout) do
        nil -> failsafe_value
        value -> value
      end

    min_limit =
      case GenServer.call(via_tuple(name), {:get_command, :min}, @default_call_timeout) do
        nil -> desired_value
        min_value -> min_value
      end

    max_limit =
      case GenServer.call(via_tuple(name), {:get_command, :max}, @default_call_timeout) do
        nil -> desired_value
        max_value -> max_value
      end

    Common.Utils.Math.constrain(desired_value, min_limit, max_limit)
  end

  def get_command_minimum(name) do
    GenServer.call(via_tuple(name), {:get_command, :min}, 50)
  end

  def get_command_maximum(name) do
    GenServer.call(via_tuple(name), {:get_command, :max}, 50)
  end

  def verify_command_within_limits(cmd_value, cmd_limit_min, cmd_limit_max) do
    if (cmd_value < cmd_limit_min) || (cmd_value > cmd_limit_max) do
      nil
    else
      cmd_value
    end
  end

  def get_most_urgent_and_return_remaining(cmds) do
    cmds = prune_old_commands(cmds)
    # Logger.debug("commands after pruning: #{inspect(cmds)}")
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

  def prune_old_commands(cmds) do
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

  defp via_tuple(name) do
    Common.ProcessRegistry.via_tuple({__MODULE__, name})
  end
end
