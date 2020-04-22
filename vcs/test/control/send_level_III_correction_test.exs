defmodule Control.SendLevelIIICorrectionTest do
  use ExUnit.Case

  setup do
    pid_config = TestConfigs.Pids.get_pid_config_plane()
    Comms.ProcessRegistry.start_link()
    Pids.System.start_link(pid_config)
    swarm_gsm_config =%{
      modules_to_monitor: [:estimator],
      state_loop_interval_ms: 50,
      initial_state: :disarmed
    }
    Swarm.Gsm.start_link(swarm_gsm_config)
    {:ok, []}
  end

  test "SendLevelIIICorrectionTest" do
    IO.puts("SendLevelIIICorrectionTest")
    op_name = :levelIII
    Comms.Operator.start_link(%{name: op_name})
    max_cmd_delta = 0.001
    IO.puts("Start Control Loop")
    controller_config = TestConfigs.Control.get_config_plane()
    Control.Controller.start_link(controller_config)
    Process.sleep(200)
    # Put into control state :auto
    assert Control.Controller.get_control_state() == nil
    new_state = :auto
    Swarm.Gsm.add_desired_control_state(new_state, [0], 1000)
    Process.sleep(100)
    assert Control.Controller.get_control_state() == new_state
    # Send PVIII command
    pv_cmd = %{heading: 0.1}
    msg_class = [2,5]
    msg_time_ms = 200
    MessageSorter.Sorter.add_message({:pv_cmds, :heading}, msg_class, msg_time_ms, pv_cmd.heading)
    Process.sleep(50)
    heading_corr = Control.Controller.get_pv_cmd(:heading)
    assert_in_delta(heading_corr, pv_cmd.heading, max_cmd_delta)
    # Send PV value
    pv_velocity_pos = %{velocity: %{x: 1, y: 0, z: 0}, position: %{x: 5, y: 10, z: -10}}
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {:pv_velocity_position, pv_velocity_pos, dt}, :pv_velocity_position, self())
    Process.sleep(200)
  end
end
