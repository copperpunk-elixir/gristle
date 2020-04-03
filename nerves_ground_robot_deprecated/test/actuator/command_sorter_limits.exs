defmodule Actuator.CommandSorterLimitsTest do
  require Logger
  use ExUnit.Case
  doctest Actuator.Controller

  alias NodeConfig.Utils.PidActuatorInterface
  test "ActuatorController - CommandSorterLimits" do
    Common.ProcessRegistry.start_link()
    Common.Utils.Comms.start_registry(:topic_registry)
    CommandSorter.System.start_link(nil)
    roll_motor = %{
      name: :roll_motor,
      channel_number: 0,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: 0.5
    }

    pitch_motor = %{
      name: :pitch_motor,
      channel_number: 1,
      reversed: false,
      min_pw_ms: 1100,
      max_pw_ms: 1900,
      cmd_limit_min: 0,
      cmd_limit_max: 1,
      failsafe_cmd: 0.5
    }
    actuators =
      PidActuatorInterface.new_actuators_config()
      |> PidActuatorInterface.add_actuator(roll_motor)
      |> PidActuatorInterface.add_actuator(pitch_motor)
    actuator_driver = :pololu
    config = %{actuator_driver: actuator_driver, actuators: actuators, actuator_loop_interval_ms: 10}
    Actuator.Controller.start_link(config)
    Common.Utils.Comms.wait_for_genserver_start(Actuator.Controller)

    cmd_classification_200 = %{priority: 0, authority: 0, time_validity_ms: 200}
    cmd_classification_400 = %{priority: 0, authority: 0, time_validity_ms: 400}
    # Add min limit to roll value
    roll_min = 0.4
    Actuator.Controller.add_actuator_cmds(:min, cmd_classification_200, %{roll_motor: roll_min})
    Process.sleep(50)
    # Add cmd that is within this limit
    roll_cmd = roll_min + 0.05
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification_400, %{roll_motor: roll_cmd})
    Process.sleep(50)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, roll_motor.failsafe_cmd) == roll_cmd
    # Add cmd that is outside this limit
    roll_cmd = roll_min - 0.05
    Actuator.Controller.add_actuator_cmds(:exact, cmd_classification_400, %{roll_motor: roll_cmd})
    Process.sleep(50)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, roll_motor.failsafe_cmd) == roll_min
    # Let limit expire and try again
    Process.sleep(150)
    assert Actuator.Controller.get_output_for_actuator_name(:roll_motor, roll_motor.failsafe_cmd) == roll_cmd
    # Add max limit to pitch value
    # roll_max
  end
end
