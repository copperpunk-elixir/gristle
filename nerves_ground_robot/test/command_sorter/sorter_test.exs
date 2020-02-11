defmodule CommandSorter.SorterTest do
  use ExUnit.Case
  doctest CommandSorter.Sorter

  test "CommandSorter Test Stack commands" do
    # Add several roll commands, check that they are all there
    max_priority = 3
    cmd_duration = 10
    index_min = 1
    index_max = 5
    cmd_start_value = index_min
    cmd_end_value = index_max
    cmds = Enum.reduce(index_min..index_max, [],  fn (t, acc) ->
      cmd = CommandSorter.CmdStruct.create_cmd(1, t, :erlang.monotonic_time(:millisecond)+t*cmd_duration, t)
      acc ++ [cmd]
    end)
    assert CommandSorter.Sorter.prune_old_commands(cmds) == cmds
    {most_urgent, remaining_valid_commands} = CommandSorter.Sorter.get_most_urgent_and_return_remaining(cmds, max_priority)
    assert most_urgent == cmd_start_value
    assert remaining_valid_commands == cmds
    # Allow enough time to pass for the first cmd to expire
    Process.sleep(cmd_duration+1)
    {most_urgent, remaining_valid_commands} = CommandSorter.Sorter.get_most_urgent_and_return_remaining(cmds, max_priority)
    assert most_urgent == cmd_start_value+1
    assert remaining_valid_commands == (cmds -- [Enum.at(cmds,0)])
    # Allow more time to pass, cmds should all be gone
    Process.sleep(index_max*cmd_duration)
    assert CommandSorter.Sorter.prune_old_commands(remaining_valid_commands) == []

    # Add cmds in a different order
    cmds = Enum.reduce(index_min..index_max, [],  fn (t, acc) ->
      cmd = CommandSorter.CmdStruct.create_cmd(1, index_max-t, :erlang.monotonic_time(:millisecond)+t*cmd_duration, t)
      acc ++ [cmd]
    end)
    {most_urgent, _remaining_valid_commands} = CommandSorter.Sorter.get_most_urgent_and_return_remaining(cmds, max_priority)
    assert most_urgent == cmd_end_value
    # Add a more urgent command
    more_urgent_value = -1
    cmds = cmds ++ [CommandSorter.CmdStruct.create_cmd(0, 100, :erlang.monotonic_time(:millisecond)+cmd_duration, more_urgent_value)]
    {most_urgent, _remaining_valid_commands} = CommandSorter.Sorter.get_most_urgent_and_return_remaining(cmds, max_priority)
    assert most_urgent == more_urgent_value
    # Let some cmds expire
    Process.sleep(round((index_max - 0.5)*cmd_duration))
    {most_urgent, remaining_valid_commands} = CommandSorter.Sorter.get_most_urgent_and_return_remaining(cmds, max_priority)
    assert most_urgent == cmd_end_value
    assert length(remaining_valid_commands) == 1
  end


  test "CommandSorter Test Single Variable" do
    Common.ProcessRegistry.start_link
    config = %{name: :roll, max_priority: 3}
    CommandSorter.Sorter.start_link(config)
    cmd_1 = %{priority: 1, authority: 3, time_validity_ms: 200, value: -1.23}
    cmd_2 = %{priority: 0, authority: 3, time_validity_ms: 400, value: 2.5}
    cmd_3 = %{priority: 0, authority: 1, time_validity_ms: 100, value: 1.4}
    cmd_4 = %{priority: 2, authority: 3, time_validity_ms: 800, value: 3.5}
    cmd_5 = %{priority: 4, authority: 0, time_validity_ms: 1000, value: 0.0}
    # stack = []
    CommandSorter.Sorter.add_command(:roll, :exact, cmd_1.priority, cmd_1.authority, cmd_1.time_validity_ms, cmd_1.value)
    # stack = [cmd_1]
    assert CommandSorter.Sorter.get_command(:roll, :exact) == cmd_1.value
    # CommandSorter.Sorter.add_command(:roll, :exact, cmd_2.priority, cmd_2.authority, cmd_2.time_validity_ms, cmd_2.value)
    # # stack = [cmd_1, cmd_2]
    # assert CommandSorter.Sorter.get_command(:roll, :exact) == cmd_2.value
    # CommandSorter.Sorter.add_command(:roll, :exact, cmd_3.priority, cmd_3.authority, cmd_3.time_validity_ms, cmd_3.value)
    # # stack = [cmd_1, cmd_2, cmd_3]
    # assert CommandSorter.Sorter.get_command(:roll, :exact) == cmd_3.value
    # Process.sleep(300)
    # # stack = [cmd_2]
    # assert CommandSorter.Sorter.get_command(:roll, :exact) == cmd_2.value
    # CommandSorter.Sorter.add_command(:roll, :exact, cmd_4.priority, cmd_4.authority, cmd_4.time_validity_ms, cmd_4.value)
    # # stack = [cmd_2, cmd_4]
    # assert CommandSorter.Sorter.get_command(:roll, :exact) == cmd_2.value
    # Process.sleep(300)
    # # stack = [cmd_4]
    # assert CommandSorter.Sorter.get_command(:roll, :exact) == cmd_4.value
    # Process.sleep(205)
    # CommandSorter.Sorter.add_command(:roll, :exact, cmd_5.priority, cmd_5.authority, cmd_5.time_validity_ms, cmd_5.value)
    # # stack = [] # cmd_5 is outside the range of priorities
    # assert CommandSorter.Sorter.get_command(:roll, :exact) == nil
  end
end
