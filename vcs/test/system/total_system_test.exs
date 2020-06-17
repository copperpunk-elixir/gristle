defmodule System.TotalSystemTest do
  use ExUnit.Case

  setup do
    # Expects node_type to be :all
    vehicle_type = Common.Utils.get_vehicle_type()
    Common.Application.start(nil,nil)

    display_config = Configuration.Module.get_config(Display.Scenic, vehicle_type, nil)
    Display.Scenic.System.start_link(display_config)
    {:ok, []}
  end

  test "Total System Test" do
    IO.puts("Start Total System Test")
    op_name = :total_system_test
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(op_name))
    interface = Configuration.Module.Cluster.get_interface()
    connection_status = VintageNet.get(["interface", interface, "lower_up"])
    if connection_status == false do
      Process.sleep(10000)
    end
    Process.sleep(2500)
    assert true
  end

end
