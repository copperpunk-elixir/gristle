defmodule System.TotalSystemTest do
  use ExUnit.Case

  setup do
    # ----- BEGIN Swarm setup -----
    heartbeat_config = %{
      heartbeat_loop_interval_ms: 100
    }
    gsm_config = %{
      modules_to_monitor: [:estimator],
      state_loop_interval_ms: 50,
      initial_state: -1
    }
    swarm_config = %{
      heartbeat: heartbeat_config,
      gsm: gsm_config
    }
    Swarm.System.start_link(swarm_config)
    # ----- END Swarm setup -----

    # ----- BEGIN Actuation setup -----
    hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    actuator_list = [:aileron, :elevator, :rudder, :throttle]
    channels_list = [0, 1, 2, 3]
    failsafes_list = [0.5, 0.5, 0.5, 0]
    sw_interface_config = TestConfigs.Actuation.get_sw_config_actuators(actuator_list, channels_list, failsafes_list)
    actuation_config = %{
      hw_interface: hw_interface_config,
      sw_interface: sw_interface_config
    }
    Actuation.System.start_link(actuation_config)
    # ----- END Actuation setup -----

    # ----- BEGIN PID setup -----
    pid_config = TestConfigs.Pids.get_pid_config_plane()
    Pids.System.start_link(pid_config)
    # ----- END PID setup -----

    # ----- BEGIN Control setup -----
    control_config = %{controller: TestConfigs.Control.get_config_plane()}
    Control.System.start_link(control_config)
    # ----- END Control setup -----

    # ----- BEGIN Estimation setup -----
    estimation_config = TestConfigs.Estimation.get_estimator_config()
    Estimation.System.start_link(estimation_config)
    # ----- END Estimation setup -----

    config = %{
      swarm_config: swarm_config,
      actuation_config: actuation_config,
      pid_config: pid_config,
      control_config: control_config,
      estimation_config: estimation_config
    }

    {:ok, [
        config: config
      ]}
  end

  test "Total System Test", context do
    IO.puts("Start Total System Test")
    op_name = :total_system_test
    Comms.Operator.start_link(%{name: op_name})
    config = context[:config]
    IO.inspect(config)
    Process.sleep(200)
    assert true
    pv_values_pos_vel_group = {:pv_values, :position_velocity}
    pv_calculated_pos_vel_group = {:pv_calculated, :position_velocity}
    pv_calculated_att_attrate_group = {:pv_calculated, :attitude_attitude_rate}
    # Actuators should be at neutral value
    aileron_neutral = config.pid_config.pids.rollrate.aileron.output_neutral
    elevator_neutral = config.pid_config.pids.pitchrate.elevator.output_neutral
    rudder_neutral = config.pid_config.pids.yawrate.rudder.output_neutral
    throttle_neutral = config.pid_config.pids.thrust.throttle.output_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:aileron) == aileron_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:elevator) == elevator_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:rudder) == rudder_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:throttle) == throttle_neutral
    # Send PV calculated values to estimator, no state yet
    new_att_attrate = %{attitude: %{roll: 0.025, pitch: -0.03, yaw: 0.13}, attitude_rate: %{rollrate: 0.20, pitchrate: 0, yawrate: -0.2354}}
    new_pos_vel = %{position: %{x: 1, y: 2, z: 3}, velocity: %{x: -1, y: -2, z: -3}}
    Comms.Operator.send_local_msg_to_group(op_name, {pv_calculated_att_attrate_group, new_att_attrate}, pv_calculated_att_attrate_group, self())
    Comms.Operator.send_local_msg_to_group(op_name, {pv_calculated_pos_vel_group, new_pos_vel}, pv_calculated_pos_vel_group, self())
    Process.sleep(200)
    # The actuators should not have changed values
    assert Actuation.SwInterface.get_output_for_actuator_name(:aileron) == aileron_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:elevator) == elevator_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:rudder) == rudder_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:throttle) == throttle_neutral
    # Send pv_cmds while the controller is still in initializing
    pv_cmd = %{rollrate: 0.2, pitchrate: -0.1, yawrate: 0.025}
    msg_class = [2,5]
    msg_time_ms = 200
    MessageSorter.Sorter.add_message({:pv_cmds, :rollrate}, msg_class, msg_time_ms, pv_cmd.rollrate)
    MessageSorter.Sorter.add_message({:pv_cmds, :pitchrate}, msg_class, msg_time_ms, pv_cmd.pitchrate)
    MessageSorter.Sorter.add_message({:pv_cmds, :yawrate}, msg_class, msg_time_ms, pv_cmd.yawrate)
    Process.sleep(200)
    assert Actuation.SwInterface.get_output_for_actuator_name(:aileron) == aileron_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:elevator) == elevator_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:rudder) == rudder_neutral
    assert Actuation.SwInterface.get_output_for_actuator_name(:throttle) == throttle_neutral
    # Move state to :disarmed, actuators should still not move
    Swarm.Gsm.add_desired_control_state(0, [1], 100)
    Process.sleep(200)
    assert Control.Controller.get_control_state() == 0
    assert Actuation.SwInterface.get_output_for_actuator_name(:aileron) == aileron_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:elevator) == elevator_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:rudder) == rudder_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:throttle) == throttle_neutral
    # # Send new cmds and pv_values
    # Swarm.Gsm.add_desired_control_state(:manual, [1], 100)
    # pv_cmd = %{rollrate: 0.2, pitchrate: -0.1, yawrate: 0.025}
    # MessageSorter.Sorter.add_message({:pv_cmds, :rollrate}, msg_class, msg_time_ms, pv_cmd.rollrate)
    # MessageSorter.Sorter.add_message({:pv_cmds, :pitchrate}, msg_class, msg_time_ms, pv_cmd.pitchrate)
    # MessageSorter.Sorter.add_message({:pv_cmds, :yawrate}, msg_class, msg_time_ms, pv_cmd.yawrate)
    # new_att_attrate = %{attitude: %{roll: 0, pitch: 0, yaw: 0}, attitude_rate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    # Comms.Operator.send_local_msg_to_group(op_name, {pv_calculated_att_attrate_group, new_att_attrate}, pv_calculated_att_attrate_group, self())
    # Process.sleep(400)
    # # Switch to :manual mode
    # # The pv_cmds should have expired, so the actuators should not have moved
    # assert Control.Controller.get_control_state() == :manual
    # assert Actuation.SwInterface.get_output_for_actuator_name(:aileron) == aileron_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:elevator) == elevator_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:rudder) == rudder_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:throttle) == throttle_neutral
    # # Add pv_cmd again
    # MessageSorter.Sorter.add_message({:pv_cmds, :rollrate}, msg_class, msg_time_ms, pv_cmd.rollrate)
    # MessageSorter.Sorter.add_message({:pv_cmds, :pitchrate}, msg_class, msg_time_ms, pv_cmd.pitchrate)
    # MessageSorter.Sorter.add_message({:pv_cmds, :yawrate}, msg_class, msg_time_ms, pv_cmd.yawrate)
    # Process.sleep(100)
    # assert Actuation.SwInterface.get_output_for_actuator_name(:aileron) > aileron_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:elevator) < elevator_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:rudder) > rudder_neutral
    # assert Actuation.SwInterface.get_output_for_actuator_name(:throttle) == throttle_neutral
    # # Switch to :semi_auto
    # pv_cmd = %{roll: -0.3, pitch: 0.01, yawrate: 0, heading: 0.2, speed: 4, altitude: 1}

  end

end
