defmodule Comms.Operator.CreateAndJoinGroupTest do
  use ExUnit.Case
  require Logger

  test "create and join group" do
    {:ok, pid} = Comms.Operator.start_link()
    Common.Utils.wait_for_genserver_start(pid)

    test_group = :abc
    Comms.Operator.join_group(test_group, self())
    Process.sleep(10)
    assert Comms.Operator.is_in_group?(test_group, self()) == true
    assert Comms.Operator.is_in_group?(:notagroup, self()) == false
    Process.sleep(150)
    groups = Comms.Operator.get_members(test_group)
    assert Enum.member?(groups, self()) == true
  end
end
