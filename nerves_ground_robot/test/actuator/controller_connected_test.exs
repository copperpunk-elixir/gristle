defmodule Actuator.ControllerTest do
  require Logger
  use ExUnit.Case
  doctest Actuator.Controller

  alias NodeConfig.Utils.PidActuatorInterface

  test "ActuatorController - connected" do
    Common.ProcessRegistry.start_link()
    Common.Utils.Comms.start_registry(:topic_registry)
    CommandSorter.System.start_link(nil)
    failsafe_cmd = 0.5
    actuators =
      PidActuatorInterface.new_actuators_config()
      |> PidActuatorInterface.add_actuator(:roll_motor, 0, false, 1100, 1900, failsafe_cmd)
      |> PidActuatorInterface.add_actuator(:pitch_motor, 1, true, 1100, 1900, failsafe_cmd)
    actuator_driver = :pololu
    config = %{actuator_driver: actuator_driver, actuators: actuators, command_priority_max: 3, actuator_loop_interval_ms: 10}

    Actuator.Controller.start_link(config)
    Common.Utils.Comms.wait_for_genserver_start(Actuator.Controller)
    cmd_classification = %{priority: 0, authority: 0, time_validity_ms: 1000}
    # Move roll actuator to min value
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification, %{roll_motor: 0})
    Process.sleep(100)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, failsafe_cmd) == 0
    # Move pitch actuator to min value, which is achieved with an input of 1, because it is reversed
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification, %{pitch_motor: 1})
    Process.sleep(1)
    assert Actuator.Controller.get_output_for_actuator_name(:pitch_motor, failsafe_cmd) == 1
    # Try sending an out of bounds value. Actuator should remain where it is
    current_position = Actuator.Controller.get_output_for_actuator_name(:roll_motor, failsafe_cmd)
    Process.sleep(1)
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification, %{roll_motor: -0.01, pitch_motor: 0})
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, failsafe_cmd) == current_position
    # Move pitch servo twice
    # Actuator.Controller.move_actuator(:pitch, 0)
    Process.sleep(1)
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification, %{pitch_motor: 0.2})
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification, %{pitch_motor: 0.5})
    Process.sleep(1)
    assert Actuator.Controller.get_output_for_actuator_name(:pitch_motor, failsafe_cmd) == 0.5
  end
end
