defmodule MessageSorter.MessageQueueTest  do
  use ExUnit.Case

  setup do
    # Comms.ProcessRegistry.start_link()
    # MessageSorter.System.start_link(:Plane)
    {:ok, []}
  end

  # TODO - rewrite this test to match the new MessageSorter .get_all_messages(:roll)) == 2
  #   assert MessageSorter.Sorter.get_value(:roll) == msg2.value
  #   Process.sleep(200)
  #   msg3 = MessageSorter.MsgStruct.create_msg([0,2,1], MessageSorter.Sorter.get_expiration_mono_ms(500), 3.0)
  #   MessageSorter.Sorter.add_message(:roll, msg3)
  #   Process.sleep(10)
  #   msg4 = MessageSorter.MsgStruct.create_msg([1,0,3], MessageSorter.Sorter.get_expiration_mono_ms(500), 4.0)
  #   MessageSorter.Sorter.add_message(:roll, msg4)
  #   Process.sleep(10)
  #   msg5 = MessageSorter.MsgStruct.create_msg([0,0,5], MessageSorter.Sorter.get_expiration_mono_ms(500), 5.0)
  #   MessageSorter.Sorter.add_message(:roll, msg5)
  #   Process.sleep(300)
  #   # Add all messages to pitch sorter, should not affect roll
  #   MessageSorter.Sorter.add_message(:pitch, msg3)
  #   MessageSorter.Sorter.add_message(:pitch, msg4)
  #   MessageSorter.Sorter.add_message(:pitch, msg5)
  #   # Pitch messages should all still be there
  #   assert length(MessageSorter.Sorter.get_all_messages(:pitch)) == 3
  #   # Back to roll
  #   # msg1 and msg2 should have expired
  #   assert MessageSorter.Sorter.get_value(:roll) == msg5.value
  #   # Add msg6, which should get rejected because the classfication doesn't match
  #   msg6 = MessageSorter.MsgStruct.create_msg([0,0], MessageSorter.Sorter.get_expiration_mono_ms(1000), -1)
  #   MessageSorter.Sorter.add_message(:roll, msg6)
  #   Process.sleep(10)
  #   assert length(MessageSorter.Sorter.get_all_messages(:roll)) == 3
  #   assert MessageSorter.Sorter.get_value(:roll) == msg5.value
  #   Process.sleep(200)
  #   # all roll messages should be expired, therefore roll
  #   # will hold the last value
  #   assert MessageSorter.Sorter.get_value(:roll) == msg5.value
  #   # all pitch messages should be expired, therefore pitch
  #   # will hold its default value
  #   assert MessageSorter.Sorter.get_value(:pitch) == default_pitch
  # end
end
