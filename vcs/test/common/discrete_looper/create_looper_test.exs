defmodule Common.DiscreteLooper.CreateLooperTest do
  use ExUnit.Case
  require Logger
  alias Common.DiscreteLooper

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()
    {:ok, []}
  end

  test "create_looper test" do
    interval = 50
    looper = DiscreteLooper.new(interval)
    sub1_config = [name: :sub1, interval_ms: 50]
    sub2_config = [name: :sub2, interval_ms: 200]
    sub3_config = [name: :sub3, interval_ms: 200]
    {:ok, sub1} =  Workshop.DummyGenserver.start_link([name: :sub1])
    {:ok, sub2} =  Workshop.DummyGenserver.start_link([name: :sub2])
    {:ok, sub3} =  Workshop.DummyGenserver.start_link([name: :sub3])
    looper = DiscreteLooper.add_member(looper, sub1, sub1_config[:interval_ms])
    looper = DiscreteLooper.add_member(looper, sub2, sub2_config[:interval_ms])
    looper = DiscreteLooper.add_member(looper, sub3, sub3_config[:interval_ms])
    Logger.debug("#{inspect(looper)}")
    Process.sleep(200)
    assert length(DiscreteLooper.get_members_for_interval(looper, 50)) == 1
    assert length(DiscreteLooper.get_members_for_interval(looper, 250)) == 0

    looper = DiscreteLooper.step(looper)
    members = DiscreteLooper.get_members_now(looper)
    assert length(members) == 1
    assert Enum.at(members, 0) == sub1
    looper = DiscreteLooper.step(looper) |> DiscreteLooper.step() |> DiscreteLooper.step()
    members = DiscreteLooper.get_members_now(looper)
    assert Enum.at(members, 0) == sub3

    looper = DiscreteLooper.update_members_for_interval(looper, [sub2], 200)
    members = DiscreteLooper.get_members_now(looper)
    assert length(members) == 1
    assert Enum.at(members, 0) == sub2
  end
end
