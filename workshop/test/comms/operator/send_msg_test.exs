defmodule Comms.Operator.SendMsgTest do
  use ExUnit.Case
  require Logger

  test "send group message" do
    {:ok, pid} = Comms.Operator.start_link()
    Common.Utils.wait_for_genserver_start(pid)

    test_group = :abc
    Comms.Operator.join_group(test_group, self())
    Comms.Operator.join_group(test_group, pid)
    Process.sleep(150)
    # Send a message to the group from pid
    msg_sent = "hello from #{inspect(pid)}"
    Logger.debug("Sending msg #{msg_sent}")
    Comms.Operator.send_msg_to_group(msg_sent, test_group, pid)
    Process.sleep(10)
    msg_received =
      receive do
      {_, msg} -> msg
    after
      1_000 -> "no msg received"
    end
    assert msg_received == msg_sent
  end
end
