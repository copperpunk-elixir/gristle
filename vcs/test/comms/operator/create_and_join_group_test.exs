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
    {:ok, pid} = Comms.Operator.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    Comms.Operator.join_group(test_group, pid)
    Process.sleep(200)
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, pid) == true
    assert Comms.Operator.is_in_group?(:notagroup, pid) == false
    Process.sleep(150)
    group_members = Comms.Operator.get_members(test_group)
    assert Enum.member?(group_members, pid) == true
  end

  test "start with empty groups" do
    config = TestConfigs.Operator.get_config()
    {:ok, pid} = Comms.Operator.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    Process.sleep(50)
    test_group = :abc
    Comms.Operator.join_group(test_group, pid)
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, pid) == true
  end

end
