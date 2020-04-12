defmodule Control.StartLoopTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Comms.Operator.start_link()
    {:ok, []}
  end

  test "start control loop" do
    IO.puts("Start Control Loop")
    process_variables = [:roll, :pitch]
    controller_config = TestConfigs.Control.get_config_with_pvs(process_variables)
    {:ok, pid} = Control.Controller.start_link(controller_config)
    Process.sleep(200)
    # All process variable groups should have been joined, so we can query them
    roll_msg_value = Control.Controller.get_pv_cmd(:roll)
    assert roll_msg_value == nil
    # Send Message to :roll
    tx_roll_value = 0.5
    MessageSorter.Sorter.add_message({:process_variable_cmd, :roll}, [0,1], 200, tx_roll_value)
    Process.sleep(100)
    roll_msg_value = Control.Controller.get_pv_cmd(:roll)
    assert roll_msg_value == tx_roll_value
    Process.sleep(150)
    roll_msg_value = Control.Controller.get_pv_cmd(:roll)
    assert roll_msg_value == nil
  end
end
