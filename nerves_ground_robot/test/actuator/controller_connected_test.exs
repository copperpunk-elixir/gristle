defmodule Actuator.ControllerTest do
  use ExUnit.Case
  doctest Actuator.Controller

  test "ActuatorController - connected" do
    Common.ProcessRegistry.start_link()
    Common.Utils.Comms.start_registry(:topic_registry)
    min_pw_ms = 1100
    max_pw_ms = 1900
    roll_actuator = %{channel_number: 0, reversed: false, min_pw_ms: min_pw_ms, max_pw_ms: max_pw_ms}
    pitch_actuator = %{channel_number: 1, reversed: true, min_pw_ms: min_pw_ms, max_pw_ms: max_pw_ms}
    config = %{port: "ttyACM1", actuators: %{roll: roll_actuator, pitch: pitch_actuator}}
    Actuator.Controller.start_link(config)
    # Move roll actuator to min value
    Actuator.Controller.move_actuator(:roll, 0)
    assert Actuator.Controller.get_output_for_actuator(:roll) == min_pw_ms
    # Move pitch actuator to min value, which is achieved with an input of 1, because it is reversed
    Actuator.Controller.move_actuator(:pitch, 1)
    assert Actuator.Controller.get_output_for_actuator(:pitch) == min_pw_ms
    # Try sending an out of bounds value. Actuator should remain where it is
    current_position = Actuator.Controller.get_output_for_actuator(:roll)
    Actuator.Controller.move_actuator(:roll, -0.01)
    assert Actuator.Controller.get_output_for_actuator(:roll) == current_position
    # Move pitch servo twice
    Actuator.Controller.move_actuator(:pitch, 0)
    Process.sleep(10)
    Actuator.Controller.move_actuator(:pitch, 0.5)
    assert Actuator.Controller.get_output_for_actuator(:pitch) == 0.5*(min_pw_ms + max_pw_ms)
  end
end
