defmodule Cluster.HealthyClusterTest do
  alias Cluster.Heartbeat, as: Hb
  use ExUnit.Case
  require Logger

  setup do
    Comms.System.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(:Plane)
    heartbeat_config = Configuration.Module.Cluster.get_heartbeat_config(0,1)
    Cluster.Heartbeat.start_link(heartbeat_config)
    {:ok, []}
  end

  test "Create healthy cluster" do
    Logger.info("Create healthy cluster")
    Comms.System.start_operator(__MODULE__)
    {_hb_class, hb_time_ms} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(__MODULE__, {:hb, :node})
    Process.sleep(400)
    assert Hb.cluster_healthy?() == false
    assert Hb.node_healthy?(0) == false
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,%{node: 1, ward: 2}, hb_time_ms}, {:hb, :node}, self())
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,%{node: 2, ward: 3}, hb_time_ms}, {:hb, :node}, self())
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:add_heartbeat,%{node: 3, ward: 0}, hb_time_ms}, {:hb, :node}, self())
    Process.sleep(150)
    assert Hb.node_healthy?(0) == true
    assert Hb.node_healthy?(1) == true
    assert Hb.node_healthy?(2) == true
    assert Hb.node_healthy?(3) == true
    assert Hb.cluster_healthy?() == true
  end
end
