defmodule Pids.LevelIIITest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "update PID-controller and check output" do
    vehicle_type = :Plane
    pid_config = Configuration.Vehicle.Plane.Pids.get_config()
    pids = pid_config.pids
    Pids.System.start_link(pid_config)

    max_delta = 0.00001
    op_name = :start_pid_test
    aileron_pid = pid_config.pids.rollrate.aileron
    Comms.System.start_operator(op_name)
    Process.sleep(300)
    pv_cmd_map = %{course_ground: 0.2, altitude: 10.0, speed: 20.0}
    pv_value_map = %{course: 0.5, altitude: 10.0, speed: 15.0, vertical: 0.0}
    airspeed = 10
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 3}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    yaw_output = Pids.Pid.get_output(:course_ground, :yaw)
    pitch_output = Pids.Pid.get_output(:tecs, :pitch)
    thrust_output = Pids.Pid.get_output(:tecs, :thrust)
    exp_yaw_output = pids.course_ground.yaw.kp*(pv_cmd_map.course_ground-pv_value_map.course)
    Logger.debug("yaw: #{yaw_output}")
    assert_in_delta(yaw_output, exp_yaw_output, max_delta)
    pv_cmd_map = %{course_flight: 0.2, altitude: 10.0, speed: 20.0}
    airspeed = 10
    dt = 0.05
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 3}, pv_cmd_map, pv_value_map,airspeed,dt},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    roll_output = Pids.Pid.get_output(:course_flight, :roll)
    exp_roll_output = pids.course_flight.roll.kp*(pv_cmd_map.course_flight-pv_value_map.course) + pids.course_flight.roll.ff.(pv_cmd_map.course_flight-pv_value_map.course,nil,airspeed)
    Logger.debug("roll: #{roll_output}")
    assert_in_delta(roll_output, exp_roll_output, max_delta)

  end

end

