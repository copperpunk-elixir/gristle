defmodule Comms.Operator.CreateAndJoinGroupTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    {:ok, []}
  end

  test "create and join group" do
    test_group = :abc
    config = TestConfigs.Operator.get_config_with_groups(test_group)
    {:ok, pid} = Comms.Operator.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    Process.sleep(50)
    Comms.Operator.join_group(test_group)
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, pid) == true
    assert Comms.Operator.is_in_group?(:notagroup, pid) == false
    Process.sleep(150)
    group_members = Comms.Operator.get_members(test_group)
    assert Enum.member?(group_members, pid) == true
  end

  test "start with empty groups" do
    config = TestConfigs.Operator.get_config_with_groups([])
    {:ok, pid} = Comms.Operator.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    Process.sleep(50)
    test_group = :abc
    Comms.Operator.join_group(test_group)
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, pid) == true
  end

end
