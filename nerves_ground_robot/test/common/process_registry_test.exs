defmodule Common.ProcessRegistryTest do
  use ExUnit.Case
  doctest Common.ProcessRegistry

  test "ProcessRegistry start Test" do
    {response, _pid} = Common.ProcessRegistry.start_link()
    assert response == :ok
    registry = :test_registry
    topic = :roll_cmd
    Common.Utils.Comms.start_registry(registry)
    # Register for registry/topic
    Common.Utils.Comms.register_subscriber(registry, topic)
    subscribers = Common.Utils.Comms.get_subscribers_for_registry_and_topic(registry, topic)
    assert Enum.member?(subscribers, self) == true
    # Unregister from registry/topic
    Common.Utils.Comms.unregister_subscriber(registry, topic)
    subscribers = Common.Utils.Comms.get_subscribers_for_registry_and_topic(registry, topic)
    assert Enum.member?(subscribers, self) == false
  end
end
