defmodule Control.SendLevelIICorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :Plane
    Comms.System.start_link()
    MessageSorter.System.start_link(vehicle_type)
    Process.sleep(100)
    pid_config = Configuration.Module.get_config(Pids, vehicle_type, nil)
    Pids.System.start_link(pid_config)
    config = Configuration.Module.get_config(Control, vehicle_type, nil)
    Control.System.start_link(config)
    {:ok, [config: pid_config]}
  end

  test "SendLevelIICorrectionTest", context do
    # Start Actuator message sorters
    pid_config = context[:config]
    aileron_neutral = pid_config.pids.rollrate.aileron.output_neutral
    elevator_neutral = pid_config.pids.pitchrate.elevator.output_neutral
    rudder_neutral = pid_config.pids.yawrate.rudder.output_neutral

    Logger.info("SendLevelIICorrectionTest")
    op_name = :levelII
    Comms.System.start_operator(op_name)
    max_cmd_delta = 0.001
    Logger.info("Start Control Loop")
    Process.sleep(200)
    # Verify that none of the PVs in PVII have a command
    assert Pids.Pid.get_output(:rollrate, :aileron) == pid_config.pids.rollrate.aileron.output_neutral
    assert Pids.Pid.get_output(:pitchrate, :elevator) == pid_config.pids.pitchrate.elevator.output_neutral
    assert Pids.Pid.get_output(:yawrate, :rudder) == pid_config.pids.yawrate.rudder.output_neutral
    # Send PVII command
    pv_cmd = %{roll: 0.12, pitch: -0.1, yaw: 0.025}
    msg_class = [2,5]
    msg_time_ms = 500
    MessageSorter.Sorter.add_message({:pv_cmds, 2}, msg_class, msg_time_ms, pv_cmd)
    # MessageSorter.Sorter.add_message({:pv_cmds, :roll}, msg_class, msg_time_ms, pv_cmd.roll)
    # MessageSorter.Sorter.add_message({:pv_cmds, :pitch}, msg_class, msg_time_ms, pv_cmd.pitch)
    # MessageSorter.Sorter.add_message({:pv_cmds, :yaw}, msg_class, msg_time_ms, pv_cmd.yaw)
    Process.sleep(150)
    roll_cmd = Control.Controller.get_pv_cmd(:roll)
    assert_in_delta(roll_cmd, pv_cmd.roll, max_cmd_delta)
    # Send PV value
    attitude = %{roll: 0.01, pitch: 0.02, yaw: 0.03}
    bodyrate = %{rollrate: 0, pitchrate: 0, yawrate: 0}
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :attitude_bodyrate}, attitude, bodyrate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(20)
    # PVII command will propogate to PVI commands, which will turn into actuator commands
    # Check actuator commands to assert that they are all the correct signs
    # depending on the conditions and commands given
    assert Pids.Pid.get_output(:rollrate, :aileron) > aileron_neutral
    assert Pids.Pid.get_output(:pitchrate, :elevator) < elevator_neutral
    assert Pids.Pid.get_output(:yawrate, :rudder) > rudder_neutral
    actuator_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds.aileron > aileron_neutral
    assert actuator_cmds.elevator < elevator_neutral
    assert actuator_cmds.rudder > rudder_neutral
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
