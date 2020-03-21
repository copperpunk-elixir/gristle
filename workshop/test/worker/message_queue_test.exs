defmodule Workshop.MessageQueueTest  do
  use ExUnit.Case
  require Logger

  test "Multiple MessageSorters" do
    MessageSorter.System.start_link(nil)
    config = %{
      registry_module: Comms.ProcessRegistry,
      registry_function: :via_tuple,
      messages: [:roll, :pitch]
    }
    # Start registry
    apply(config.registry_module, :start_link, [])
    Enum.each(config.messages, fn message_type ->
      Logger.debug("Message type: #{message_type}")
      process_via_tuple = apply(config.registry_module, config.registry_function, [MessageSorter, message_type])
      MessageSorter.System.start_sorter(process_via_tuple)
    end)

    # Add messages to MessageSorter
    msg1 = MessageSorter.MsgStruct.create_msg([1,0,0], 500, 1.0)
    msg2 = MessageSorter.MsgStruct.create_msg([0,2,0], 500, 2.0)
    msg3 = MessageSorter.MsgStruct.create_msg([0,2,1], 500, 3.0)
    msg4 = MessageSorter.MsgStruct.create_msg([1,0,3], 500, 4.0)
    msg5 = MessageSorter.MsgStruct.create_msg([0,0,5], 500, 5.0)
    msg6 = MessageSorter.MsgStruct.create_msg([0,0], 1000, -1)

    roll_via_tuple = apply(config.registry_module, config.registry_function, [MessageSorter, :roll])
    pitch_via_tuple = apply(config.registry_module, config.registry_function, [MessageSorter, :pitch])
    MessageSorter.Sorter.add_message(roll_via_tuple, msg1)
    Process.sleep(10)
    assert length(MessageSorter.Sorter.get_all_messages(roll_via_tuple)) == 1
    assert MessageSorter.Sorter.get_message(roll_via_tuple).value == msg1.value
    assert MessageSorter.Sorter.get_message(roll_via_tuple).classification == msg1.classification
    assert MessageSorter.Sorter.get_value(roll_via_tuple) == msg1.value

    MessageSorter.Sorter.add_message(roll_via_tuple, msg2)
    Process.sleep(10)
    assert length(MessageSorter.Sorter.get_all_messages(roll_via_tuple)) == 2
    assert MessageSorter.Sorter.get_value(roll_via_tuple) == msg2.value
    Process.sleep(200)
    MessageSorter.Sorter.add_message(roll_via_tuple, msg3)
    Process.sleep(10)
    MessageSorter.Sorter.add_message(roll_via_tuple, msg4)
    Process.sleep(10)
    MessageSorter.Sorter.add_message(roll_via_tuple, msg5)
    Process.sleep(300)
    # Add all messages to pitch sorter, should not affect roll
    MessageSorter.Sorter.add_message(pitch_via_tuple, msg1)
    MessageSorter.Sorter.add_message(pitch_via_tuple, msg2)
    MessageSorter.Sorter.add_message(pitch_via_tuple, msg3)
    # Back to roll
    # msg1 and msg2 should have expired
    assert MessageSorter.Sorter.get_value(roll_via_tuple) == msg5.value
    # Add msg6, which should get rejected because the classfication doesn't match
    MessageSorter.Sorter.add_message(roll_via_tuple, msg6)
    Process.sleep(10)
    assert length(MessageSorter.Sorter.get_all_messages(roll_via_tuple)) == 3
    assert MessageSorter.Sorter.get_value(roll_via_tuple) == msg5.value
    Process.sleep(200)
    # all roll messages should be expired
    assert MessageSorter.Sorter.get_value(roll_via_tuple) == nil
    # Pitch messages should all still be there
    assert length(MessageSorter.Sorter.get_all_messages(pitch_via_tuple)) == 3
  end
end
