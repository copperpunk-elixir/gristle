defmodule Actuator.CommandSorterLimitsTest do
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
    cmd_classification_200 = %{priority: 0, authority: 0, time_validity_ms: 200}
    cmd_classification_400 = %{priority: 0, authority: 0, time_validity_ms: 400}
    # Add limit to roll value
    roll_min = 0.4
    Actuator.Controller.add_actuator_cmds(:min, cmd_classification_200, %{roll_motor: roll_min})
    # Add cmd that is within this limit
    roll_cmd = roll_min + 0.05
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification_400, %{roll_motor: roll_cmd})
    Process.sleep(50)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, failsafe_cmd) == roll_cmd
    # Add cmd that is outside this limit
    roll_cmd = roll_min - 0.05
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification_400, %{roll_motor: roll_cmd})
    Process.sleep(50)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, failsafe_cmd) == roll_min
    # Let limit expire and try again
    Process.sleep(150)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, failsafe_cmd) == roll_cmd
  end
end
