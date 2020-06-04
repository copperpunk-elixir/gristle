defmodule Vehicle.FourWheelRobotControlTest do
  use ExUnit.Case
  require Logger

  setup do
    vehicle_type = :FourWheelRobot

    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    MessageSorter.System.start_link(vehicle_type)
    # ----- BEGIN Actuation setup -----

    actuation_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Actuation)
    Actuation.System.start_link(actuation_config)
    # ----- END Actuation setup -----

    # ----- BEGIN PID setup -----
    pid_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Pids)
    Pids.System.start_link(pid_config)
    # ----- END PID setup -----

    # ----- BEGIN Control setup -----
    control_config = Configuration.Vehicle.get_config_for_vehicle_and_module(vehicle_type, Control)
    Control.System.start_link(control_config)
    # ----- END Control setup -----
    config = %{
      actuation_config: actuation_config,
      pid_config: pid_config,
      control_config: control_config
    }

    {:ok, [config: config]}
  end

  test "Drive Forward Test", context do
    config = context[:config]
    pid_config = config.pid_config
    {pv_msg_class, pv_msg_time} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(Navigation.Navigator, :pv_cmds)
    {cs_msg_class, cs_msg_time} = Configuration.Generic.get_message_sorter_classification_time_validity_ms(Navigation.Navigator, :control_state)
    Logger.info("pv class/time: #{inspect(pv_msg_class)}/#{pv_msg_time}")
    Logger.info("Drive Forward Test")
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    Process.sleep(300)
    neutral = 0.5
    actuator_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds.front_left == neutral
    assert actuator_cmds.front_right == neutral
    assert actuator_cmds.rear_right == neutral
    assert actuator_cmds.rear_left == neutral
    # Send thrust command (full forward)
    pv_att_att_rate = %{attitude: %{roll: 0.0, pitch: 0.0, yaw: 0.0}, bodyrate: %{rollrate: 0, pitchrate: 0, yawrate: 0}}
    dt = 0.05
    MessageSorter.Sorter.add_message(:control_state, cs_msg_class, 2000, 1)
    Process.sleep(200)
    # Full throttle
    MessageSorter.Sorter.add_message({:pv_cmds, 1},pv_msg_class, 2000, %{thrust: 1.0, yawrate: 0.0} )
    Process.sleep(200)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(120)
    actuator_cmds_full_throttle = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds_full_throttle.front_left > neutral
    assert actuator_cmds_full_throttle.front_right > neutral
    assert actuator_cmds_full_throttle.rear_right > neutral
    assert actuator_cmds_full_throttle.rear_left > neutral
    MessageSorter.Sorter.add_message({:pv_cmds, 1},pv_msg_class, 2000, %{thrust: 1.0, yawrate: 1.0} )
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(150)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(50)
    actuator_cmds_right_turn = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds_right_turn.front_left > actuator_cmds_full_throttle.front_left
    assert actuator_cmds_right_turn.front_right < actuator_cmds_full_throttle.front_right
    assert actuator_cmds_right_turn.rear_right < actuator_cmds_full_throttle.rear_right
    assert actuator_cmds_right_turn.rear_left > actuator_cmds_full_throttle.rear_left
    # Try to go backwards
    MessageSorter.Sorter.add_message({:pv_cmds, 1},pv_msg_class, 2000, %{thrust: -1.0, yawrate: 0.0} )
    Process.sleep(150)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(150)
    actuator_cmds_full_throttle_reverse = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds_full_throttle_reverse.front_left < neutral
    assert actuator_cmds_full_throttle_reverse.front_right < neutral
    assert actuator_cmds_full_throttle_reverse.rear_right < neutral
    assert actuator_cmds_full_throttle_reverse.rear_left < neutral
    # Half throttle (for reference in the next test)
    MessageSorter.Sorter.add_message({:pv_cmds, 1},pv_msg_class, 2000, %{thrust: 0.5, yawrate: 0.0} )
    Process.sleep(150)
    Logger.warn("half throttle")
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(150)
    actuator_cmds_half_throttle = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds_half_throttle.front_left > neutral
    assert actuator_cmds_half_throttle.front_right > neutral
    assert actuator_cmds_half_throttle.rear_right > neutral
    assert actuator_cmds_half_throttle.rear_left > neutral
    # Turn left
    MessageSorter.Sorter.add_message({:pv_cmds, 1},pv_msg_class, 2000, %{thrust: 0.5, yawrate: -0.4} )
    Process.sleep(150)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_values, :attitude_bodyrate}, pv_att_att_rate, dt}, {:pv_values, :attitude_bodyrate}, self())
    Process.sleep(150)
    actuator_cmds_right_turn = MessageSorter.Sorter.get_value(:actuator_cmds)
    assert actuator_cmds_right_turn.front_left < actuator_cmds_half_throttle.front_left
    assert actuator_cmds_right_turn.front_right > actuator_cmds_half_throttle.front_right
    assert actuator_cmds_right_turn.rear_right > actuator_cmds_half_throttle.rear_right
    assert actuator_cmds_right_turn.rear_left < actuator_cmds_half_throttle.rear_left

    Process.sleep(300)
  end
end
