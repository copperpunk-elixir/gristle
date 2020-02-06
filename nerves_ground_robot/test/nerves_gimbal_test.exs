defmodule NervesGroundRobotTest do
  use ExUnit.Case
  doctest Actuator.Controller

  test "Actuator Controller" do
    assert Actuator.Controller.build_message(0, 1500) == [0x84, 0, 112, 46, 43]
    assert Actuator.Controller.build_message(1, 1100) == [0x84, 1, 48, 34, 36]
    assert Actuator.Controller.output_to_ms(0.25, false, 1100, 1900) == 1300
    assert Actuator.Controller.output_to_ms(0.25, true, 1100, 1900) == 1700
    assert Actuator.Controller.output_to_ms(1.5, true, 1100, 1900) == nil
    assert Actuator.Controller.calculate_checksum([0x83, 0x01]) == 23
  end
end
