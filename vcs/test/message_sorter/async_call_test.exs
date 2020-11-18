defmodule MessageSorter.AsyncCallTest  do
  use ExUnit.Case
  require Logger
  alias Workshop.MsgSorterRx

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    {:ok, []}
  end

  test "async call test" do
    name = "test"
    classification = [0,0]
    time_validity_ms = 100
    sorter_config =
    [
      name: name,
      default_message_behavior: :default_value,
      default_value: nil,
      value_type: :number
    ]
    MessageSorter.Sorter.start_link(sorter_config)
    MsgSorterRx.start_link(name)
    Process.sleep(500)
    Logger.info("request value")
    MsgSorterRx.request_value(name)
    Process.sleep(50)
    value = MsgSorterRx.get_value(name)
    assert value == nil

    new_value = 5
    MessageSorter.Sorter.add_message(name, classification, time_validity_ms, new_value)
    Process.sleep(20)
    MsgSorterRx.request_value(name)
    Process.sleep(50)
    value = MsgSorterRx.get_value(name)
    assert value == new_value

  end
end
