defmodule Pids.FourWheelRobotDirectionTest do
  use ExUnit.Case
  require Logger
  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    {:ok, []}
  end

 test "FourWheelRobot motor direction", context do
    vehicle_type = :FourWheelRobot
    pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
    actuation_config = Configuration.Vehicle.get_actuation_config(vehicle_type, :all)
    MessageSorter.System.start_link(vehicle_type)
    Pids.System.start_link(pid_config)
    Actuation.System.start_link(actuation_config)

    max_delta = 0.001
    op_name = :start_pid_test
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(op_name))
    Process.sleep(500)
    # Turn to the right
    pv_cmd_map = %{yawrate: 0.1}
    pv_value_map = %{bodyrate: %{yawrate: 0}}
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    current_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    Logger.info("current cmds: #{inspect(current_cmds)}")
    assert current_cmds.front_left > 0.0
    assert current_cmds.front_right == 0
    assert current_cmds.left_direction > 0.5
    assert current_cmds.right_direction < 0.5
    # Turn to the left
    pv_cmd_map = %{yawrate: -0.1}
    pv_value_map = %{bodyrate: %{yawrate: 0}}
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    current_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    Logger.info("current cmds: #{inspect(current_cmds)}")
    assert current_cmds.front_left == 0.0
    assert current_cmds.front_right > 0
    assert current_cmds.left_direction < 0.5
    assert current_cmds.right_direction > 0.5
    # Go forward
    pv_cmd_map = %{yawrate: 0.0, thrust: 0.5}
    pv_value_map = %{bodyrate: %{yawrate: 0}}
    Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 1}, pv_cmd_map, pv_value_map,0.05},{:pv_cmds_values, 1}, self())
    Process.sleep(100)
    current_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    Logger.info("current cmds: #{inspect(current_cmds)}")
    assert current_cmds.front_left > 0.0
    assert current_cmds.front_right > 0.0
    assert current_cmds.left_direction > 0.5
    assert current_cmds.right_direction > 0.5
  end
end
