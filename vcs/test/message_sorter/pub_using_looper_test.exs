defmodule MessageSorter.PubUsingLooperTest  do
  use ExUnit.Case
  require Logger
  alias Workshop.MsgSorterRx

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    msg_sorter_name = :test

    # Common.Utils.start_link_redundant(Registry, Registry, [keys: :duplicate, name: MessageSorterRegistry])
    {:ok, [msg_sorter_name: msg_sorter_name]}
  end

  test "async call test", context do
    sorter_name = context[:msg_sorter_name]
    classification = [0,0]
    time_validity_ms = 2000
    sorter_config =
      [
        name: sorter_name,
        default_message_behavior: :default_value,
        default_value: nil,
        value_type: :number,
        publish_interval_ms: 50
      ]
    MessageSorter.Sorter.start_link(sorter_config)
    MsgSorterRx.start_link("sub1")
    MsgSorterRx.start_link("sub2")
    MsgSorterRx.join_message_sorter("sub1", sorter_name, 50)
    MsgSorterRx.join_message_sorter("sub2", sorter_name, 250)
    Process.sleep(500)
    new_value = 5
    MessageSorter.Sorter.add_message(sorter_name, classification, time_validity_ms, new_value)
    Process.sleep(1200)
    assert MsgSorterRx.get_value("sub1", sorter_name)== new_value
    assert MsgSorterRx.get_value("sub2", sorter_name)== new_value
    Process.sleep(time_validity_ms)
    assert MsgSorterRx.get_value("sub1", sorter_name)== sorter_config[:default_value]
    assert MsgSorterRx.get_value("sub2", sorter_name)== sorter_config[:default_value]
  end
end
