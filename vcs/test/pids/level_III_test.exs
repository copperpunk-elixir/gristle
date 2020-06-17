# defmodule Pids.LevelIIITest do
#   use ExUnit.Case

#   setup do
#     vehicle_type = :Plane
#     Comms.ProcessRegistry.start_link()
#     Process.sleep(100)
#     pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
#     Pids.System.start_link(pid_config)
#     MessageSorter.System.start_link(vehicle_type)
#     # MessageSorter.System.start_sorter(%{name: {:pv_cmds, :roll}, default_message_behavior: :default_value, default_value: 0})
#     # MessageSorter.System.start_sorter(%{name: {:pv_cmds, :yaw}, default_message_behavior: :default_value, default_value: 0})

#     {:ok, [
#         config: %{
#           pid_config: pid_config,
#         }
#       ]}
#   end

#   test "LevelIITest", context do
#     IO.puts("LevelIIITest")
#     max_rate_delta = 0.001
#     op_name = :batch_test
#     Comms.Operator.start_link(Configuration.Generic.get_operator_config(op_name))
#     dt = 0.05
#     config = context[:config]
#     Process.sleep(200)
#     # Setup parameters
#     pids = config.pid_config.pids
#     course_pid = pids.course

#     # ----- BEGIN COURSE-to-ROLL/YAW RUDDER TEST -----
#     # Update course, which affects both roll and yaw
#     pv_cmd_map = %{course: 0.3}
#     pv_value_map = %{course: -0.2}
#     course_corr= pv_cmd_map.course - pv_value_map.course
#     # Level III correction
#     Comms.Operator.send_local_msg_to_group(op_name, {{:pv_cmds_values, 3}, pv_cmd_map, pv_value_map, dt}, {:pv_cmds_values, 3}, self())
#     Process.sleep(50)
#     exp_course_roll_output = course_corr*course_pid.roll.kp
#     exp_course_yaw_output = course_corr*course_pid.yaw.kp
#     exp_roll_output =
#     (exp_course_roll_output + course_pid.roll.output_neutral)*Map.get(course_pid.roll, :weight, 1)
#       |> Common.Utils.Math.constrain(course_pid.roll.output_min, course_pid.roll.output_max)
#     exp_yaw_output = (exp_course_yaw_output + course_pid.yaw.output_neutral)*Map.get(course_pid.yaw, :weight, 1)
#     |> Common.Utils.Math.constrain(course_pid.yaw.output_min, course_pid.yaw.output_max)
#     Process.sleep(50)
#     roll_output = Pids.Pid.get_output(:course, :roll, Map.get(course_pid.roll,:weight,1))
#     yaw_output = Pids.Pid.get_output(:course, :yaw, Map.get(course_pid.yaw,:weight,1))
#     attitude_cmd = MessageSorter.Sorter.get_value({:pv_cmds, 2})
#     roll_cmd = attitude_cmd.roll# MessageSorter.Sorter.get_value({:pv_cmds, :roll})
#     yaw_cmd = attitude_cmd.yaw # MessageSorter.Sorter.get_value({:pv_cmds, :yaw})

#     assert_in_delta(roll_output, exp_roll_output, max_rate_delta)
#     assert_in_delta(roll_cmd, exp_roll_output, max_rate_delta)
#     assert_in_delta(yaw_output, exp_yaw_output, max_rate_delta)
#     assert_in_delta(yaw_cmd, exp_yaw_output, max_rate_delta)
#   end

# end

