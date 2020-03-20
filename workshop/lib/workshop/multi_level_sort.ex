defmodule Workshop.MultiLevelSort do

  def create_messages() do
    msg1 = MessageSorter.MsgStruct.create_msg([1,0,0], 10000, 1.0)
    msg2 = MessageSorter.MsgStruct.create_msg([0,2,0], 10000, 2.0)
    msg3 = MessageSorter.MsgStruct.create_msg([0,2,1], 10000, 3.0)
    msg4 = MessageSorter.MsgStruct.create_msg([1,0,3], 10000, 4.0)
    msg5 = MessageSorter.MsgStruct.create_msg([0,0,5], 10000, 5.0)
    [msg1, msg2, msg3, msg4, msg5]
  end
end
