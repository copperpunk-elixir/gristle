defmodule Control.StorePvCmdsTest  do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Boss.System.common_prepare()

    MessageSorter.System.start_link(Configuration.Module.MessageSorter.get_config("T28", nil))
    Control.System.start_link([])
    {:ok, []}
  end

  test "Store pv_cmds test" do
    # sorter_configs = Configuration.Vehicle.Plane.Control.get_sorter_configs()
    # Enum.each(sorter_configs, fn config ->
    #   MessageSorter.Sorter.start_link(config)
    # end)
    Process.sleep(200)
    MessageSorter.Sorter.add_message(:control_state, [0,0], 2000, 1)
    MessageSorter.Sorter.add_message({:pv_cmds, 1}, [0,0], 2000, %{thrust: 0.1, rollrate: 0.2, pitchrate: 0.3, yawrate: 0.4})
    MessageSorter.Sorter.add_message({:pv_cmds, 2}, [0,0], 2000, %{thrust: 0.2, roll: -0.3, pitch: -0.4, yaw: -0.5})
    MessageSorter.Sorter.add_message({:pv_cmds, 3}, [0,0], 2000, %{course_flight: 1.1, speed: 2.2, altitude: 3.3})
    Process.sleep(5000)
  end
end
