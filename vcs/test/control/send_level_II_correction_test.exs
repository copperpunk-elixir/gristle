defmodule Control.SendLevelIICorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    pid_config = TestConfigs.Pids.get_pid_config_plane()
    Comms.ProcessRegistry.start_link()
    Pids.System.start_link(pid_config)
    swarm_gsm_config =%{
      modules_to_monitor: [:estimator],
      state_loop_interval_ms: 50,
    }
    Cluster.Gsm.start_link(swarm_gsm_config)
    {:ok, [config: pid_config]}
  end

  test "SendLevelIICorrectionTest", context do
    # Start Actuator message sorters
    pid_config = context[:config]
    aileron_neutral = pid_config.pids.rollrate.aileron.output_neutral
    elevator_neutral = pid_config.pids.pitchrate.elevator.output_neutral
    rudder_neutral = pid_config.pids.yawrate.rudder.output_neutral

    MessageSorter.System.start_link()
    actuator_sorter_config = %{
      name: :actuator_cmds,
      default_message_behavior: :default_value,
      default_value: %{aileron: aileron_neutral, elevator: elevator_neutral, rudder: rudder_neutral},
      value_type: :map
    }
    MessageSorter.System.start_sorter(actuator_sorter_config)
    # MessageSorter.System.start_sorter(%{name: {:actuator_cmds, :aileron}, default_message_behavior: :default_value, default_value: aileron_neutral})
    # MessageSorter.System.start_sorter(%{name: {:actuator_cmds, :elevator}, default_message_behavior: :default_value, default_value: elevator_neutral})
    # MessageSorter.System.start_sorter(%{name: {:actuator_cmds, :rudder}, default_message_behavior: :default_value, default_value: rudder_neutral})
    Logger.info("SendLevelIICorrectionTest")
    op_name = :levelII
    Comms.Operator.start_link(%{name: op_name})
    max_cmd_delta = 0.001
    Logger.info("Start Control Loop")
    config = %{controller: TestConfigs.Control.get_config_plane()}
    Control.System.start_link(config)
    Process.sleep(200)
    # Put into control state :auto
    assert Control.Controller.get_control_state() == -1
    new_state = 2#:semi_auto
    Cluster.Gsm.add_desired_control_state(new_state, [0], 1000)
    Process.sleep(100)
    assert Control.Controller.get_control_state() == new_state
    Logger.info(inspect(pid_config.pids))
    # Verify that none of the PVs in PVII have a command
    assert Pids.Pid.get_output(:rollrate, :aileron) == pid_config.pids.rollrate.aileron.output_neutral
    assert Pids.Pid.get_output(:pitchrate, :elevator) == pid_config.pids.pitchrate.elevator.output_neutral
    assert Pids.Pid.get_output(:yawrate, :rudder) == pid_config.pids.yawrate.rudder.output_neutral
    # Send PVII command
    pv_cmd = %{roll: 0.12, pitch: -0.1, yaw: 0.025}
    msg_class = [2,5]
    msg_time_ms = 200
    MessageSorter.Sorter.add_message({:pv_cmds, 2}, msg_class, msg_time_ms, pv_cmd)
    # MessageSorter.Sorter.add_message({:pv_cmds, :roll}, msg_class, msg_time_ms, pv_cmd.roll)
    # MessageSorter.Sorter.add_message({:pv_cmds, :pitch}, msg_class, msg_time_ms, pv_cmd.pitch)
    # MessageSorter.Sorter.add_message({:pv_cmds, :yaw}, msg_class, msg_time_ms, pv_cmd.yaw)
    Process.sleep(50)
    roll_cmd = Control.Controller.get_pv_cmd(:roll)
    assert_in_delta(roll_cmd, pv_cmd.roll, max_cmd_delta)
    # Send PV value
    pv_att_att_rate = %{attitude: %{roll: 0.01, pitch: 0.02, yaw: 0.03}, body_rate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :attitude_body_rate}, pv_att_att_rate, dt}, {:pv_values, :attitude_body_rate}, self())
    Process.sleep(20)
    # PVII command will propogate to PVI commands, which will turn into actuator commands
    # Check actuator commands to assert that they are all the correct signs
    # depending on the conditions and commands given
    assert Pids.Pid.get_output(:rollrate, :aileron) > aileron_neutral
    assert Pids.Pid.get_output(:pitchrate, :elevator) < elevator_neutral
    assert Pids.Pid.get_output(:yawrate, :rudder) < rudder_neutral
    actuator_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds.aileron > aileron_neutral
    assert actuator_cmds.elevator < elevator_neutral
    assert actuator_cmds.rudder < rudder_neutral
    # assert MessageSorter.Sorter.get_value({:actuator_cmds, :aileron}) > aileron_neutral
    # assert MessageSorter.Sorter.get_value({:actuator_cmds, :elevator}) < elevator_neutral
    # assert MessageSorter.Sorter.get_value({:actuator_cmds, :rudder}) < rudder_neutral
    Process.sleep(msg_time_ms)
    actuator_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds.aileron == aileron_neutral
    assert actuator_cmds.elevator == elevator_neutral
    assert actuator_cmds.rudder == rudder_neutral
    # assert MessageSorter.Sorter.get_value({:actuator_cmds, :aileron}) == aileron_neutral
    # assert MessageSorter.Sorter.get_value({:actuator_cmds, :elevator}) == elevator_neutral
    # assert MessageSorter.Sorter.get_value({:actuator_cmds, :rudder}) == rudder_neutral
  end
end
