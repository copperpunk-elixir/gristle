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
    Logger.debug("config: #{inspect(config)}")
    {:ok, %{
        commands: %{
          exact: [],
          min: [],
          max: []
        },
        max_priority: config.max_priority
     }
    }
  end

  @impl GenServer
  def handle_cast({:add_command, cmd_type_min_max_exact, priority, authority, expiration_mono_ms, value}, state) do
    # Remove any commands that have the same priority/authority (there should be at most 1)
    commands_list = get_in(state.commands, [cmd_type_min_max_exact])
    unique_cmds = Enum.reject(commands_list, fn cmd ->
      (cmd.priority==priority) && (cmd.authority==authority)
    end)
    new_cmd = CommandSorter.CmdStruct.create_cmd(priority, authority, expiration_mono_ms, value)
    # new_cmd = %{priority: priority, authority: authority, expiration_mono_ms: expiration_mono_ms, value: value}
    # Logger.debug("new cmd: #{inspect(new_cmd)}")
    {:noreply, put_in(state, [:commands, cmd_type_min_max_exact], [new_cmd | unique_cmds])}
  end

  @impl GenServer
  def handle_call({:get_command, cmd_type_min_max_exact}, _from, state) do
    # Logger.debug("Available commands: #{inspect(state.commands)}")
    commands_list = get_in(state.commands, [cmd_type_min_max_exact])
    Logger.debug("#{inspect(state)}")
    Logger.debug("#{inspect(commands_list)}")
    {cmd, remaining_valid_commands} = get_most_urgent_and_return_remaining(commands_list, state.max_priority)
    # Logger.debug("Most urgent cmd: #{inspect(cmd)}")
    {:reply, cmd, put_in(state, [:commands, cmd_type_min_max_exact], remaining_valid_commands)}
  end

  def add_command(name, cmd_type_min_max_exact, priority, authority, time_validity_ms, value) do
    expiration_mono_ms = :erlang.monotonic_time(:millisecond) + time_validity_ms
    GenServer.cast(via_tuple(name), {:add_command, cmd_type_min_max_exact, priority, authority, expiration_mono_ms, value})
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

  def get_most_urgent_and_return_remaining(cmds, max_priority) do
    cmds = prune_old_commands(cmds)
    # Logger.debug("commands after pruning: #{inspect(cmds)}")
    most_urgent_stream = sort_most_urgent_to_stream(cmds, 0, max_priority)
    if most_urgent_stream == [] do
      {nil, []}
    else
      cmd_struct = Enum.sort_by(most_urgent_stream, &(&1.authority)) |> Enum.at(0)
      {cmd_struct.value, cmds}
    end
  end

  def prune_old_commands(cmds) do
    current_time_ms = :erlang.monotonic_time(:millisecond)
    Enum.reject(cmds, &(&1.expiration_mono_ms < current_time_ms))
  end

  defp sort_most_urgent_to_stream(cmds, priority, max_priority) do
    most_urgent = Stream.reject(cmds, &(&1.priority > priority))
    valid_value = Enum.at(most_urgent, 0)
    if (valid_value == nil) do
      if (priority < max_priority) do
        sort_most_urgent_to_stream(cmds, priority+1, max_priority)
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
