defmodule Comms.Operator.SendMsgTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(50)
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "send group message" do
    pid = self()
    IO.puts("SendMsgTest")
    test_group = :abc
    config = TestConfigs.Operator.get_config()
    op_name = config.name
    Comms.Operator.start_link(config)
    Comms.Operator.join_group(op_name, test_group, pid)
    MessageSorter.System.start_sorter(%{name: test_group})
    # Must allow time for joining group
    Process.sleep(200)
    # Send a message to the group from pid
    tx_msg = "hello from #{inspect(pid)}"
    IO.puts("Sending msg #{inspect(tx_msg)}")
    Comms.Operator.send_global_msg_to_group(op_name, tx_msg, test_group, nil)
    Process.sleep(100)
    rx_msg = receive do
      {_info, msg} -> msg
    after 100 ->
        :error
    end
    assert rx_msg == tx_msg
    # Leave group, send message
    Comms.Operator.leave_group(op_name, test_group, pid)
    # Allow for test_group to be purged from the group list
    # Let the tx_msg expire from the MessageSorter queue
    Process.sleep(150)
    assert Comms.Operator.is_in_group?(test_group, pid) == false
    Comms.Operator.send_local_msg_to_group(op_name, tx_msg, test_group, nil)
    rx_msg = receive do
      {_info, msg} -> msg
    after 100 ->
        :none
    end
    assert rx_msg == :none
  end
end
