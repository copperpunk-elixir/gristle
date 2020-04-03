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
    # Must allow time for joining group
    Process.sleep(200)
    # Send a message to the group from pid
    msg_value = "hello from #{inspect(pid)}"
    tx_msg = {:global_msg, test_group, [0], 200, msg_value}
    Logger.debug("Sending msg #{inspect(tx_msg)}")
    Comms.Operator.send_msg_to_group(tx_msg, test_group, nil)
    Process.sleep(100)
    assert Comms.Operator.get_message_count() == 1
    rx_msg = MessageSorter.Sorter.get_value(test_group)
    assert rx_msg == msg_value
    # Leave group, send message
    Comms.Operator.leave_group(test_group)
    # Msg should still be available in the MessageSorter queue
    assert rx_msg == msg_value
    # Allow for test_group to be purged from the group list
    # Let the tx_msg expire from the MessageSorter queue
    Process.sleep(150)
    assert MessageSorter.Sorter.get_value(test_group) == nil
    Comms.Operator.send_msg_to_group(tx_msg, test_group, nil)
    Process.sleep(50)
    rx_msg = MessageSorter.Sorter.get_value(test_group)
    assert rx_msg == nil
  end
end
