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
    config = %{controller: TestConfigs.Control.get_config_plane()}
    Control.System.start_link(config)
    Process.sleep(200)
    # Put into control state :auto
    assert Control.Controller.get_control_state() == nil
    new_state = :auto
    Swarm.Gsm.add_desired_control_state(new_state, [0], 1000)
    Process.sleep(100)
    assert Control.Controller.get_control_state() == new_state
    # Verify that none of the PVs in PVII have a command
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :roll}), 0, max_cmd_delta)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :pitch}), 0, max_cmd_delta)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :yaw}), 0, max_cmd_delta)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :thrust}), 0, max_cmd_delta)
    # Send PVIII command
    pv_cmd = %{heading: :math.pi()/180*10, speed: 10, altitude: 5}
    msg_class = [2,5]
    msg_time_ms = 200
    MessageSorter.Sorter.add_message({:pv_cmds, :heading}, msg_class, msg_time_ms, pv_cmd.heading)
    MessageSorter.Sorter.add_message({:pv_cmds, :speed}, msg_class, msg_time_ms, pv_cmd.speed)
    Process.sleep(50)
    heading_corr = Control.Controller.get_pv_cmd(:heading)
    assert_in_delta(heading_corr, pv_cmd.heading, max_cmd_delta)
    # Send PV value
    heading = :math.pi()/180*20
    speed = 5
    vx = speed*:math.cos(heading)
    vy = speed*:math.sin(heading)
    pv_velocity_pos = %{velocity: %{x: vx, y: vy, z: 0}, position: %{x: 5, y: 10, z: 10}}
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :position_velocity}, pv_velocity_pos, dt}, {:pv_values, :position_velocity}, self())
    Process.sleep(100)
    # Now check PVII commands. Assert that they are all the correct signs
    # Depending on the conditions and commands given
    assert MessageSorter.Sorter.get_value({:pv_cmds, :roll}) < 0
    assert MessageSorter.Sorter.get_value({:pv_cmds, :yaw}) < 0
    assert MessageSorter.Sorter.get_value({:pv_cmds, :pitch}) < 0
    assert MessageSorter.Sorter.get_value({:pv_cmds, :thrust}) > 0
    Process.sleep(msg_time_ms)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :roll}), 0, max_cmd_delta)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :pitch}), 0, max_cmd_delta)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :yaw}), 0, max_cmd_delta)
    assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :thrust}), 0, max_cmd_delta)
  end
end
