defmodule Control.SendLevelIIICorrectionTest do
  use ExUnit.Case
  require Logger

  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    pid_config = Configuration.Vehicle.Plane.Pids.get_config()
    Pids.System.start_link(pid_config)
    MessageSorter.System.start_link(:Plane)
    {:ok, [config: pid_config]}
  end

  test "SendLevelIIICorrectionTest", context do
    pid_config = context[:config]
    aileron_neutral = pid_config.pids.rollrate.aileron.output_neutral
    elevator_neutral = pid_config.pids.pitchrate.elevator.output_neutral
    rudder_neutral = pid_config.pids.yawrate.rudder.output_neutral

    IO.puts("SendLevelIIICorrectionTest")
    op_name = :levelIII
    Comms.Operator.start_link(%{name: op_name})
    max_cmd_delta = 0.001
    IO.puts("Start Control Loop")
    config = Configuration.Vehicle.Plane.Control.get_config()
    Control.System.start_link(config)
    Process.sleep(200)
    # Verify that none of the PVs in PVII have a command
    pv_1_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 1})
    pv_2_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    assert_in_delta(pv_1_cmds.thrust, 0, max_cmd_delta)
    assert_in_delta(pv_2_cmds.roll, 0, max_cmd_delta)
    assert_in_delta(pv_2_cmds.pitch, 0, max_cmd_delta)
    assert_in_delta(pv_2_cmds.yaw, 0, max_cmd_delta)

    assert Pids.Pid.get_output(:rollrate, :aileron) == pid_config.pids.rollrate.aileron.output_neutral
    assert Pids.Pid.get_output(:pitchrate, :elevator) == pid_config.pids.pitchrate.elevator.output_neutral
    assert Pids.Pid.get_output(:yawrate, :rudder) == pid_config.pids.yawrate.rudder.output_neutral

    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :pitch}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :yaw}), 0, max_cmd_delta)
    # assert_in_delta(MessageSorter.Sorter.get_value({:pv_cmds, :thrust}), 0, max_cmd_delta)
    # Send PVIII command
    pv_3_cmds = %{course: :math.pi()/180*10, speed: 10, altitude: 5}
    msg_class = [2,5]
    msg_time_ms = 500
    MessageSorter.Sorter.add_message({:pv_cmds, 3}, msg_class, msg_time_ms, pv_3_cmds)
    # MessageSorter.Sorter.add_message({:pv_cmds, :course}, msg_class, msg_time_ms, pv_cmd.course)
    # MessageSorter.Sorter.add_message({:pv_cmds, :speed}, msg_class, msg_time_ms, pv_cmd.speed)
    Process.sleep(50)
    course_cmd = Control.Controller.get_pv_cmd(:course)
    assert_in_delta(course_cmd, pv_3_cmds.course, max_cmd_delta)
    # Send PV value
    course = :math.pi()/180*20
    speed = 5
    vx = speed*:math.cos(course)
    vy = speed*:math.sin(course)
    pv_velocity_pos = %{velocity: %{north: vx, east: vy, down: 0}, position: %{latitude: 5, longitude: 10, altitude: 10}}
    pv_att_att_rate = %{attitude: %{roll: 0, pitch: 0, yaw: 0}, bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :position_velocity}, pv_velocity_pos, dt}, {:pv_values, :position_velocity}, self())
    Process.sleep(50)
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(100)

    # Now check PVII commands. Assert that they are all the correct signs
    # Depending on the conditions and commands given
    pv_2_cmds = MessageSorter.Sorter.get_value({:pv_cmds, 2})
    IO.puts("pv_2_cmds: #{inspect(pv_2_cmds)}")
    assert pv_2_cmds.thrust > 0
    assert pv_2_cmds.roll < 0
    assert pv_2_cmds.pitch < 0
    assert pv_2_cmds.yaw < 0
    # Level 1
    assert Pids.Pid.get_output(:rollrate, :aileron) < aileron_neutral
    assert Pids.Pid.get_output(:pitchrate, :elevator) < elevator_neutral
    assert Pids.Pid.get_output(:yawrate, :rudder) < rudder_neutral
    actuator_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds.aileron < aileron_neutral
    assert actuator_cmds.elevator < elevator_neutral
    assert actuator_cmds.rudder < rudder_neutral

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
