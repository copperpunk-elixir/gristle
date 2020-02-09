defmodule TrackVehicle.ControllerTest do
  require Logger
  use ExUnit.Case
  doctest TrackVehicle.Controller

  delta_compare = 1.0e-6

  Common.Utils.Comms.start_registry(:topic_registry)
  Common.ProcessRegistry.start_link

  config = NodeConfig.TrackVehicle.get_config()

  TrackVehicle.Controller.start_link(config.track_vehicle_controller)

  # Very that actuators are not armed until commanded
  assert TrackVehicle.Controller.get_parameter(:actuators_ready) == false
  TrackVehicle.Controller.arm_actuators()
  assert TrackVehicle.Controller.get_parameter(:actuators_ready) == true
  assert TrackVehicle.Controller.get_parameter(:actuator_timer) != nil
  assert TrackVehicle.Controller.get_parameter(:none) == nil

  # Update command, verify that is has been stored
  new_cmd = %{speed: 1.0, turn: -0.2}
  TrackVehicle.Controller.update_speed_and_turn_cmd(new_cmd)
  assert_in_delta(TrackVehicle.Controller.get_parameter(:speed_cmd), new_cmd.speed, delta_compare)
  assert_in_delta(TrackVehicle.Controller.get_parameter(:turn_cmd), new_cmd.turn, delta_compare)

  # Calculate track commands based on speed/turn/ratio
  speed = 1.0
  turn = 1.0
  speed_to_turn_ratio = 1.0
  {left_track_cmd, right_track_cmd} = TrackVehicle.Controller.calculate_track_cmd_for_speed_and_turn(speed, turn, speed_to_turn_ratio)
  assert_in_delta(left_track_cmd, 1.0, delta_compare)
  assert_in_delta(right_track_cmd,0.5 + 0.5*(1.0 - 1.0/1.0), delta_compare)

  # Again, Calculate track commands based on speed/turn/ratio
  speed = -0.5
  turn = 0.5
  speed_to_turn_ratio = 1.5
  {left_track_cmd, right_track_cmd} = TrackVehicle.Controller.calculate_track_cmd_for_speed_and_turn(speed, turn, speed_to_turn_ratio)
  assert_in_delta(left_track_cmd, 0.5 + 0.5*(-0.5 + 0.5/1.5), delta_compare)
  assert_in_delta(right_track_cmd,0.5 + 0.5*(-0.5 - 0.5/1.5), delta_compare)

  # Ensure that out of bounds values are contrained
  {left_track_cmd, right_track_cmd} = TrackVehicle.Controller.calculate_track_cmd_for_speed_and_turn(1.0, 1.0, 0.25)
  assert_in_delta(left_track_cmd, 1.0, delta_compare)
  assert_in_delta(right_track_cmd, 0.5, delta_compare)

  {left_track_cmd, right_track_cmd} = TrackVehicle.Controller.calculate_track_cmd_for_speed_and_turn(-1.0, 0.5, 1.0)
  assert_in_delta(left_track_cmd, 0.25, delta_compare)
  assert_in_delta(right_track_cmd, 0.0, delta_compare)

end
