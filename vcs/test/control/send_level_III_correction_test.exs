defmodule Control.SendLevelIIICorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    pid_config = TestConfigs.Pids.get_pid_config_plane()
    Comms.ProcessRegistry.start_link()
    Pids.System.start_link(pid_config)
    swarm_gsm_config =%{
      modules_to_monitor: [:estimator],
      state_loop_interval_ms: 50
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
    assert Control.Controller.get_control_state() == -1
    new_state = 3#:auto
    Swarm.Gsm.add_desired_control_state(new_state, [0], 1000)
    Process.sleep(100)
    assert Control.Controller.get_control_state() == new_state
    # Verify that none of the PVs in PVII have a command
    pv_1_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 1})
    pv_2_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert_in_delta(pv_1_cmds.thrust, 0, max_cmd_delta)
    assert_in_delta(pv_2_cmds.roll, 0, max_cmd_delta)
    assert_in_delta(pv_2_cmds.pitch, 0, max_cmd_delta)
    assert_in_delta(pv_2_cmds.yaw, 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :pitch}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :yaw}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :thrust}), 0, max_cmd_delta)
    # Send PVIII command
    pv_3_cmds = %{heading: :math.pi()/180*10, speed: 10, altitude: 5}
    msg_class = [2,5]
    msg_time_ms = 500
    MessageSorter.Sorter.add_message({:pv_cmds, 3}, msg_class, msg_time_ms, pv_3_cmds)
    # MessageSorter.Sorter.add_message({:pv_cmds, :heading}, msg_class, msg_time_ms, pv_cmd.heading)
    # MessageSorter.Sorter.add_message({:pv_cmds, :speed}, msg_class, msg_time_ms, pv_cmd.speed)
    Process.sleep(50)
    heading_cmd = Control.Controller.get_pv_cmd(:heading)
    assert_in_delta(heading_cmd, pv_3_cmds.heading, max_cmd_delta)
    # Send PV value
    heading = :math.pi()/180*20
    speed = 5
    vx = speed*:math.cos(heading)
    vy = speed*:math.sin(heading)
    pv_velocity_pos = %{velocity: %{x: vx, y: vy, z: 0}, position: %{x: 5, y: 10, z: 10}}
    pv_att_att_rate = %{attitude: %{roll: 0, pitch: 0, yaw: 0}, attitude_rate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :position_velocity}, pv_velocity_pos, dt}, {:pv_values, :position_velocity}, self())
    Process.sleep(50)
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :attitude_attitude_rate}, pv_att_att_rate, dt}, {:pv_values, :attitude_attitude_rate}, self())
    Process.sleep(100)

    # Now check PVII commands. Assert that they are all the correct signs
    # Depending on the conditions and commands given
    pv_2_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    IO.puts("pv_2_cmds: #{inspect(pv_2_cmds)}")
    assert pv_2_cmds.thrust > 0
    assert pv_2_cmds.roll < 0
    assert pv_2_cmds.pitch < 0
    assert pv_2_cmds.yaw < 0
    
    # assert MessageSorter.Sorter.get_value({:pv_cmds, :roll}) < 0
    # assert MessageSorter.Sorter.get_value({:pv_cmds, :yaw}) < 0
    # assert MessageSorter.Sorter.get_value({:pv_cmds, :pitch}) < 0
    # assert MessageSorter.Sorter.get_value({:pv_cmds, :thrust}) > 0
    Process.sleep(msg_time_ms)
    pv_2_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert pv_2_cmds.thrust == 0
    assert pv_2_cmds.roll == 0
    assert pv_2_cmds.pitch == 0
    assert pv_2_cmds.yaw == 0
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :roll}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :pitch}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :yaw}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :thrust}), 0, max_cmd_delta)
  end
end
