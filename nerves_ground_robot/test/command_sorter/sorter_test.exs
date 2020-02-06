defmodule CommandSorter.SorterTest do
  use ExUnit.Case
  doctest CommandSorter.Sorter

  test "CommandSorter Test Single Variable" do
    Common.ProcessRegistry.start_link
    config = %{name: :roll, max_priority: 3}
    CommandSorter.Sorter.start_link(config)
    cmd_1 = %{priority: 1, authority: 3, expiration_mono_ms: (:erlang.monotonic_time(:millisecond)+200), value: -1.23}
    cmd_2 = %{priority: 0, authority: 3, expiration_mono_ms: (:erlang.monotonic_time(:millisecond)+400), value: 2.5}
    cmd_3 = %{priority: 0, authority: 1, expiration_mono_ms: (:erlang.monotonic_time(:millisecond)+100), value: 1.4}
    cmd_4 = %{priority: 2, authority: 3, expiration_mono_ms: (:erlang.monotonic_time(:millisecond)+800), value: 3.5}
    # stack = []
    CommandSorter.Sorter.add_command(:roll, cmd_1.priority, cmd_1.authority, cmd_1.expiration_mono_ms, cmd_1.value)
    # stack = [cmd_1]
    assert CommandSorter.Sorter.get_command(:roll) == cmd_1.value
    CommandSorter.Sorter.add_command(:roll, cmd_2.priority, cmd_2.authority, cmd_2.expiration_mono_ms, cmd_2.value)
    # stack = [cmd_1, cmd_2]
    assert CommandSorter.Sorter.get_command(:roll) == cmd_2.value
    CommandSorter.Sorter.add_command(:roll, cmd_3.priority, cmd_3.authority, cmd_3.expiration_mono_ms, cmd_3.value)
    # stack = [cmd_1, cmd_2, cmd_3]
    assert CommandSorter.Sorter.get_command(:roll) == cmd_3.value
    Process.sleep(300)
    # stack = [cmd_2]
    assert CommandSorter.Sorter.get_command(:roll) == cmd_2.value
    CommandSorter.Sorter.add_command(:roll, cmd_4.priority, cmd_4.authority, cmd_4.expiration_mono_ms, cmd_4.value)
    # stack = [cmd_2, cmd_4]
    assert CommandSorter.Sorter.get_command(:roll) == cmd_2.value
    Process.sleep(300)
    # stack = [cmd_4]
    assert CommandSorter.Sorter.get_command(:roll) == cmd_4.value
    Process.sleep(200)
    assert CommandSorter.Sorter.get_command(:roll) == nil
  end
end
