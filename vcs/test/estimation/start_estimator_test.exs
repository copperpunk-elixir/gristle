defmodule Estimation.StartEstimatorTest do
  use ExUnit.Case

  setup do
    config = TestConfigs.Estimation.get_estimator_config()
    Estimation.System.start_link(config)
    MessageSorter.System.start_link()
    MessageSorter.System.start_sorter(%{name: :estimator_health, default_message_behavior: :default_value, default_value: :unhealthy})
    Comms.TestMemberAllGroups.start_link()
    {:ok, [config: config]}
  end

  test "StartEstimatorTest", context do
    pv_values_pos_vel_group = {:pv_values, :position_velocity}
    pv_calculated_pos_vel_group = {:pv_calculated, :position_velocity}
    pv_calculated_att_attrate_group = {:pv_calculated, :attitude_attitude_rate}
    IO.puts("StartEstimatorTest")
    op_name = :estimator_test
    Comms.Operator.start_link(%{name: op_name})
    config = context[:config]
    new_att_attrate = %{attitude: %{roll: 2.5, pitch: -3, yaw: 130}, attitude_rate: %{rollrate: 20, pitchrate: 0, yawrate: -23.54}}
    new_pos_vel = %{position: %{x: 1, y: 2, z: 3}, velocity: %{x: -1, y: -2, z: -3}}
    Process.sleep(110)
    Comms.Operator.send_local_msg_to_group(op_name, {pv_calculated_att_attrate_group, new_att_attrate}, pv_calculated_att_attrate_group, self())
    Comms.Operator.send_local_msg_to_group(op_name, {pv_calculated_pos_vel_group, new_pos_vel}, pv_calculated_pos_vel_group, self())
    Process.sleep(200)
    pos_x_calc = Comms.TestMemberAllGroups.get_value([:pv_calculated, :position, :x])
    vel_y_calc = Comms.TestMemberAllGroups.get_value([:pv_calculated, :velocity, :y])
    assert pos_x_calc == new_pos_vel.position.x
    assert vel_y_calc == new_pos_vel.velocity.y
    pos_x_imu = Comms.TestMemberAllGroups.get_value([:pv_values_estimator, :position, :x])
    rollrate = Comms.TestMemberAllGroups.get_value([:pv_values_estimator, :attitude_rate, :rollrate])
    assert pos_x_imu == new_pos_vel.position.x
    assert rollrate == new_att_attrate.attitude_rate.rollrate

  end
end