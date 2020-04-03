defmodule Comms.Operator.SendMsgTest do
  use ExUnit.Case
  require Logger

  test "send group message" do
    {:ok, pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    test_group = :abc
    config = TestConfigs.Operator.get_config_with_groups(test_group)
    {:ok, pid} = Comms.Operator.start_link(config)
    Common.Utils.wait_for_genserver_start(pid)
    Process.sleep(100)
    # Send a message to the group from pid
    msg_value = "hello from #{inspect(pid)}"
    msg_sent = {:global_msg, test_group, [0], 1000, msg_value}
    Logger.debug("Sending msg #{inspect(msg_sent)}")
    Comms.Operator.send_msg_to_group(msg_sent, test_group, nil)
    Process.sleep(100)
    assert Comms.Operator.get_message_count() == 1
    rx_msg = MessageSorter.Sorter.get_value(test_group)
    assert rx_msg == msg_value
  end
end
