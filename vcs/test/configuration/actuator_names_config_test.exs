defmodule Configuration.ActuatorNamesConfigTest do
  use ExUnit.Case
  require Logger


  test "Get Actuator config for actuators" do
    actuator_names = [:aileron, :elevator, :rudder, :throttle]
    actuation_sw_config = Configuration.Vehicle.get_actuation_sw_config(actuator_names, :all)
    assert actuation_sw_config.actuators.aileron.channel_number == 0
    assert actuation_sw_config.actuators.elevator.channel_number == 1
    assert actuation_sw_config.actuators.rudder.channel_number == 2
    assert actuation_sw_config.actuators.throttle.failsafe_cmd == 0.0
    assert actuation_sw_config.actuators.aileron.failsafe_cmd == 0.5
  end
end
