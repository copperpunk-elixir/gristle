defmodule MessageSorter.PubUsingLooperTest  do
  use ExUnit.Case
  require Logger
  alias Workshop.MsgSorterRx

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    msg_sorter_name = :test

    Common.Utils.start_link_redundant(Registry, Registry, [keys: :duplicate, name: MessageSorterRegistry])
    {:ok, [msg_sorter_name: msg_sorter_name]}
  end

  test "async call test", context do
    name = context[:msg_sorter_name]
    classification = [0,0]
    time_validity_ms = 100
    sorter_config =
      [
        name: name,
        default_message_behavior: :default_value,
        default_value: nil,
        value_type: :number,
        publish_interval_ms: 50
      ]
    MessageSorter.Sorter.start_link(sorter_config)
    MsgSorterRx.start_link(name)
    MsgSorterRx.join_message_sorter(name, 50)
    Process.sleep(500)
    Logger.info("request value")
    new_value = 5
    MessageSorter.Sorter.add_message(name, classification, time_validity_ms, new_value)
    Process.sleep(2000)
    value = MsgSorterRx.get_value(name)
    assert value == new_value
  end
end
