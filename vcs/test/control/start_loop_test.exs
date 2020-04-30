defmodule Control.StartLoopTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(50)
    Comms.Operator.start_link(%{name: :start_loop_test})
    {:ok, []}
  end

  test "start control loop" do
    IO.puts("Start Control Loop")
    config = %{controller: TestConfigs.Control.get_config_car()}
    Control.System.start_link(config)
    Process.sleep(200)
    # All process variable groups should have been joined, so we can query them
    thrust_value = Control.Controller.get_pv_cmd(:thrust)
    assert thrust_value == 0
    # Send Message to :thrust
    pv_cmd = %{thrust: 0.5, yawrate: 0.2, speed: 10}
    MessageSorter.Sorter.add_message({:pv_cmds, 2}, [0,1], 200, %{thrust: pv_cmd.thrust})
    Process.sleep(100)
    thrust_value = Control.Controller.get_pv_cmd(:thrust)
    assert thrust_value == pv_cmd.thrust
    Process.sleep(150)
    thrust_value = Control.Controller.get_pv_cmd(:thrust)
    assert thrust_value == 0
  end
end
