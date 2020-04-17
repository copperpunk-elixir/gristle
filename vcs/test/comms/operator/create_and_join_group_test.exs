defmodule Comms.Operator.CreateAndJoinGroupTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    {:ok, []}
  end

  test "create and join group" do
    IO.puts("Create and Join Group")
    test_group = :abc
    config = TestConfigs.Operator.get_config()
    op_name = config.name
    {:ok, pid} = Comms.Operator.start_link(config)
    Comms.Operator.join_group(op_name, test_group, pid)
    Process.sleep(300)
    assert Comms.Operator.is_in_group?(test_group, pid) == true
    assert Comms.Operator.is_in_group?(:notagroup, pid) == false
    Process.sleep(150)
    group_members = Comms.Operator.get_global_members(op_name, test_group)
    IO.puts("test group members: #{inspect(group_members)}")
    assert Enum.member?(group_members, pid) == true
  end

  test "start with empty groups" do
    config = TestConfigs.Operator.get_config()
    op_name = config.name
    {:ok, pid} = Comms.Operator.start_link(config)
    Process.sleep(50)
    test_group = :abc
    Comms.Operator.join_group(op_name, test_group, pid)
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, pid) == true
  end

end
