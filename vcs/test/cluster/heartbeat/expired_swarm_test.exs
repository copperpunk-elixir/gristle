defmodule Cluster.ExpiredClusterTest do
  alias Cluster.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    config = %{
      heartbeat: %{
        heartbeat_loop_interval_ms: 100,
        node: 0,
        ward: 1
      }
    }
    Cluster.System.start_link(config)
    {:ok, []}
  end

  test "Healthy cluster expires to unhealthy cluster" do
    Comms.Operator.start_link(%{name: __MODULE__})
    Logger.info("Create temporarily healthy cluster")
    Process.sleep(400)
    {hb_class, hb_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, {:hb, :node})
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,%{node: 1, ward: 2}, hb_time_ms}, {:hb, :node}, self())
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,%{node: 2, ward: 0}, hb_time_ms}, {:hb, :node}, self())
    Process.sleep(250)
    assert Hb.cluster_healthy?() == true
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,%{node: 1, ward: 2}, hb_time_ms}, {:hb, :node}, self())
    Process.sleep(400)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == false
    assert Hb.node_healthy?(2) == false
    assert Hb.cluster_healthy?() == false
  end

end
