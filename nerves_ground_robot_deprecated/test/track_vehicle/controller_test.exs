defmodule TrackVehicle.ControllerTest do
  require Logger
  use ExUnit.Case
  doctest TrackVehicle.Controller

  delta_compare = 1.0e-6

  Common.Utils.Comms.start_registry(:topic_registry)
  Common.ProcessRegistry.start_link
  CommandSorter.System.start_link(nil)

  config = NodeConfig.TrackVehicle.get_config()

  TrackVehicle.Controller.start_link(config.track_vehicle_controller)
  Common.Utils.Comms.wait_for_genserver_start(TrackVehicle.Controller)
  Logger.debug("how about that")
  Process.sleep(200)
  # Very that actuators are not armed until commanded
  assert TrackVehicle.Controller.get_parameter(:actuators_ready) == false
  TrackVehicle.Controller.arm_actuators()
  assert TrackVehicle.Controller.get_parameter(:actuators_ready) == true
  assert TrackVehicle.Controller.get_parameter(:none) == nil

  # Update command, verify that is has been stored
  track_vehicle_cmd_classification = %{priority: 0, authority: 0, time_validity_ms: 200}
  new_cmd = %{speed: 1.0, turn: -0.2}
  TrackVehicle.Controller.update_speed_and_turn_cmd(:exact, track_vehicle_cmd_classification, new_cmd)
  Process.sleep(20)
  assert_in_delta(CommandSorter.Sorter.get_command({TrackVehicle.Controller, :speed}, nil), new_cmd.speed, delta_compare)
  assert_in_delta(CommandSorter.Sorter.get_command({TrackVehicle.Controller, :turn}, nil), new_cmd.turn, delta_compare)

  # # Calculate track commands based on speed/turn/ratio
  speed = 1.0
  turn = 1.0
  {left_track_cmd, right_track_cmd} = TrackVehicle.Controller.calculate_track_cmd_for_speed_and_turn(speed, turn)
  assert_in_delta(left_track_cmd, 1.0, delta_compare)
  assert_in_delta(right_track_cmd,0.0, delta_compare)

  # # Again, Calculate track commands based on speed/turn/ratio
  speed = -0.5
  turn = 0.5
  {left_track_cmd, right_track_cmd} = TrackVehicle.Controller.calculate_track_cmd_for_speed_and_turn(speed, turn)
  assert_in_delta(left_track_cmd, -0.5, delta_compare)
  assert_in_delta(right_track_cmd,-0.5*:math.sqrt(1-0.25), delta_compare)

  # Ensure that out of bounds values are contrained
  # First, clear out any valid commands
  Process.sleep(250)
  speed_config = Common.Utils.Enum.get_map_nested_inside_list_containing_key_value(config.track_vehicle_controller.pid_actuator_links, :process_variable, :speed)
  turn_config = Common.Utils.Enum.get_map_nested_inside_list_containing_key_value(config.track_vehicle_controller.pid_actuator_links, :process_variable, :turn)
  new_cmd = %{speed: 1.0, turn: 2.2}
  TrackVehicle.Controller.update_speed_and_turn_cmd(:exact, track_vehicle_cmd_classification, new_cmd)
  Process.sleep(20)
  assert_in_delta(CommandSorter.Sorter.get_command({TrackVehicle.Controller, :speed}, turn_config.failsafe_cmd), new_cmd.speed, delta_compare)
  assert_in_delta(CommandSorter.Sorter.get_command({TrackVehicle.Controller, :turn}, turn_config.failsafe_cmd), turn_config.failsafe_cmd, delta_compare)
  # Repeat with invalid speed command
  Process.sleep(250)
  new_cmd = %{speed: -1.4, turn: -0.5}
  TrackVehicle.Controller.update_speed_and_turn_cmd(:exact, track_vehicle_cmd_classification, new_cmd)
  Process.sleep(20)
  assert_in_delta(CommandSorter.Sorter.get_command({TrackVehicle.Controller, :speed}, speed_config.failsafe_cmd), speed_config.failsafe_cmd, delta_compare)
  assert_in_delta(CommandSorter.Sorter.get_command({TrackVehicle.Controller, :turn}, turn_config.failsafe_cmd), new_cmd.turn, delta_compare)

end
