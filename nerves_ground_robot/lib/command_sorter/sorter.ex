defmodule CommandSorter.Sorter do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start CommandSorter: #{inspect(config.name)}")
    GenServer.start_link(__MODULE__, config, name: via_tuple(config.name))
  end

  @impl GenServer
  def init(config) do
    Logger.debug("config: #{inspect(config)}")
    {:ok, %{
        commands: [],
        max_priority: config.max_priority
     }
    }
  end

  @impl GenServer
  def handle_cast({:add_command, priority, authority, expiration_mono_ms, value}, state) do
    new_cmd = CommandSorter.CmdStruct.create_cmd(priority, authority, expiration_mono_ms, value)
    # new_cmd = %{priority: priority, authority: authority, expiration_mono_ms: expiration_mono_ms, value: value}
    # Logger.debug("new cmd: #{inspect(new_cmd)}")
    {:noreply, %{state | commands: [new_cmd | state.commands]}}
  end

  @impl GenServer
  def handle_call(:get_command, _from, state) do
    # Logger.debug("Available commands: #{inspect(state.commands)}")
    {cmd, remaining_valid_commands} = get_most_urgent(state.commands, state.max_priority)
    # Logger.debug("Most urgent cmd: #{inspect(cmd)}")
    {:reply, cmd, %{state | commands: remaining_valid_commands}}
  end

  def add_command(name, priority, authority, expiration_mono_ms, value) do
    GenServer.cast(via_tuple(name), {:add_command, priority, authority, expiration_mono_ms, value})
  end

  def get_command(name) do
    GenServer.call(via_tuple(name), :get_command, 60000)
  end

  defp get_most_urgent(cmds, max_priority) do
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

  defp prune_old_commands(cmds) do
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
