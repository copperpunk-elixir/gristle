defmodule Actuation.HwInterfacePololuTest do
  use ExUnit.Case
  require Logger
  setup do
    {:ok, []}
  end

  # test "Start HWInterface. Connect to Pololu Maestro. Change actuator values" do
  #   Logger.info("Connect servo to channel 0 if real actuation is desired")
  #   config = Configuration.Vehicle.Plane.Actuation.get_config()
  #   Actuation.HwInterface.start_link(config.hw_interface)
  #   Process.sleep(100)
  #   aileron = config.sw_interface.actuators.aileron
  #   # Set output to min_value
  #   Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_min)
  #   assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.min_pw_ms
  #   Process.sleep(100)
  #   # Set output to max value
  #   Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_max)
  #   assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.max_pw_ms
  #   Process.sleep(100)
  #   # Set output to neutral value
  #   Actuation.HwInterface.set_output_for_actuator(aileron, 0.5*(aileron.cmd_limit_min + aileron.cmd_limit_max))
  #   assert Actuation.HwInterface.get_output_for_actuator(aileron) == 0.5*(aileron.min_pw_ms + aileron.max_pw_ms)
  #   Process.sleep(100)
  #   # Reverse servo and set to min value -> should yield
  #   aileron = %{aileron | reversed: true}
  #   Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_min)
  #   assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.max_pw_ms
  # end

  test "Start HWInterface without Pololu plugged in" do
    config = Configuration.Vehicle.Plane.Actuation.get_config()
    Actuation.HwInterface.start_link(config.hw_interface)
    Process.sleep(1000)
    aileron = config.sw_interface.actuators.aileron
    Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_min)
    assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.min_pw_ms
  end
end
