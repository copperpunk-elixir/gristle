defmodule Workshop.MessageQueueTest  do
  alias MessageSorter.Sorter
  use ExUnit.Case
  require Logger

  test "Multiple MessageSorters" do
    MessageSorter.System.start_link()
    default_pitch = -3
    config = %{
      registry_module: Comms.ProcessRegistry,
      registry_function: :via_tuple,
      messages: [
        %{name: :roll,
          default_message_behavior: :last
        },
        %{name: :pitch,
          default_message_behavior: :default_value,
          default_value: default_pitch
        }
        ]
    }
    # Start registry
    {:ok, pid} = Comms.ProcessRegistry.start_link()
    Common.Utils.wait_for_genserver_start(pid)
    Enum.each(config.messages, fn msg_config ->
      Logger.debug("Message name: #{msg_config.name}")
      MessageSorter.System.start_sorter(msg_config)
    end)

    # Add messages to MessageSorter
    msg1 = MessageSorter.MsgStruct.create_msg([1,0,0], Sorter.get_expiration_mono_ms(500), 1.0)
    Sorter.add_message(:roll, msg1)
    Process.sleep(10)
    assert length(Sorter.get_all_messages(:roll)) == 1
    assert Sorter.get_message(:roll).value == msg1.value
    assert Sorter.get_message(:roll).classification == msg1.classification
    assert Sorter.get_value(:roll) == msg1.value

    msg2 = MessageSorter.MsgStruct.create_msg([0,2,0], Sorter.get_expiration_mono_ms(500), 2.0)
    Sorter.add_message(:roll, msg2)
    Process.sleep(10)
    assert length(Sorter.get_all_messages(:roll)) == 2
    assert Sorter.get_value(:roll) == msg2.value
    Process.sleep(200)
    msg3 = MessageSorter.MsgStruct.create_msg([0,2,1], Sorter.get_expiration_mono_ms(500), 3.0)
    Sorter.add_message(:roll, msg3)
    Process.sleep(10)
    msg4 = MessageSorter.MsgStruct.create_msg([1,0,3], Sorter.get_expiration_mono_ms(500), 4.0)
    Sorter.add_message(:roll, msg4)
    Process.sleep(10)
    msg5 = MessageSorter.MsgStruct.create_msg([0,0,5], Sorter.get_expiration_mono_ms(500), 5.0)
    Sorter.add_message(:roll, msg5)
    Process.sleep(300)
    # Add all messages to pitch sorter, should not affect roll
    Sorter.add_message(:pitch, msg3)
    Sorter.add_message(:pitch, msg4)
    Sorter.add_message(:pitch, msg5)
    # Pitch messages should all still be there
    assert length(Sorter.get_all_messages(:pitch)) == 3
    # Back to roll
    # msg1 and msg2 should have expired
    assert Sorter.get_value(:roll) == msg5.value
    # Add msg6, which should get rejected because the classfication doesn't match
    msg6 = MessageSorter.MsgStruct.create_msg([0,0], Sorter.get_expiration_mono_ms(1000), -1)
    Sorter.add_message(:roll, msg6)
    Process.sleep(10)
    assert length(Sorter.get_all_messages(:roll)) == 3
    assert Sorter.get_value(:roll) == msg5.value
    Process.sleep(200)
    # all roll messages should be expired, therefore roll
    # will hold the last value
    assert Sorter.get_value(:roll) == msg5.value
    # all pitch messages should be expired, therefore pitch
    # will hold its default value
    assert Sorter.get_value(:pitch) == default_pitch
  end
end
