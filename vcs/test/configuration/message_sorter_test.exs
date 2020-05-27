defmodule Configuration.MessageSorterTest do
  use ExUnit.Case
  require Logger


  test "Message Sorter classfication and time_validity" do
    {pid_act_class, pid_act_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(Pids.System, :actuator_cmds)
    assert pid_act_class == [0,1]
    assert pid_act_time_ms == 200

    {hb_class, hb_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(Cluster.Heartbeat, {:hb, :node})
    assert hb_class == nil
    assert hb_time_ms == 500

    {unknown_class, unknown_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, :nonexistent)
     assert unknown_class == nil
     assert unknown_time_ms == 0


  end
end
