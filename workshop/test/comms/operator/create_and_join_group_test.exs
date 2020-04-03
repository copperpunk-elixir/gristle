defmodule Comms.Operator.CreateAndJoinGroupTest do
  use ExUnit.Case

  test "create and join group" do
    test_group = :abc
    config = TestConfigs.Operator.get_config_with_groups(test_group)
    {:ok, pid} = Comms.Operator.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)

    Comms.Operator.join_group(test_group, self())
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, self()) == true
    assert Comms.Operator.is_in_group?(:notagroup, self()) == false
    Process.sleep(150)
    groups = Comms.Operator.get_members(test_group)
    assert Enum.member?(groups, self()) == true
  end
end
