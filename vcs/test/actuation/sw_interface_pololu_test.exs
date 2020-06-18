defmodule Actuation.SwInterfacePololuTest do
  use ExUnit.Case
  require Logger
  setup do
    Comms.ProcessRegistry.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Start HWInterface. Connect to Pololu Maestro. Change actuator values" do
    # actuator_name = :aileron
    # hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    # actuator_list = [actuator_name]
    # channels_list = [0]
    # failsafes_list = [0.5]
    # sw_interface_config = TestConfigs.Actuation.get_sw_config_actuators(actuator_list, channels_list, failsafes_list)
    # config = %{
    #   hw_interface: hw_interface_config,
    #   sw_interface: sw_interface_config
    # }
    vehicle_type = :Plane
    vehicle_module = Module.concat(Configuration.Vehicle, vehicle_type)
    MessageSorter.System.start_link(vehicle_type)
    Process.sleep(200)
    actuator_name= :aileron
    config = Configuration.Module.get_config(Actuation,vehicle_type, :all)
    actuators = config.sw_interface.actuators
    Logger.info("Connect servo to channel 0 if real actuation is desired")
    Actuation.System.start_link(config)
    Process.sleep(100)
    # Test actuator values
    actuator = Map.get(actuators, actuator_name)
    # With no valid commands, the actuator output should be the failsafe_cmd
    Process.sleep(150)
    failsafe_output = 0.5*(actuator.min_pw_ms + actuator.max_pw_ms)
    assert Actuation.HwInterface.get_output_for_actuator(actuator) == failsafe_output
    # Send min_cmd to Actuator
    current_cmds = MessageSorter.Sorter.get_value(:actuator_cmds)
    new_cmds = Map.merge(current_cmds, %{actuator_name => actuator.cmd_limit_min})
    MessageSorter.Sorter.add_message(:actuator_cmds, [0], 400, new_cmds)
    Process.sleep(200)
    assert Actuation.HwInterface.get_output_for_actuator(actuator) == actuator.min_pw_ms
    new_cmds = Map.merge(current_cmds, %{actuator_name => actuator.cmd_limit_max})
    MessageSorter.Sorter.add_message(:actuator_cmds, [0], 1000, new_cmds)
    Process.sleep(300)
    assert Actuation.HwInterface.get_output_for_actuator(actuator) == actuator.max_pw_ms
  end
end
