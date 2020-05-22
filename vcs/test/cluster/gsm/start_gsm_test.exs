defmodule Cluster.Gsm.StartGsmTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(50)
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "Start GSM" do
    IO.puts("ClusterGsm: Start Gsm")
    Cluster.System.start_link()
    assert Cluster.Gsm.get_state() == -1
  end

end
