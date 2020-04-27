defmodule Actuation.SwInterfacePololuTest do
  use ExUnit.Case

  setup do
    Comms.ProcessRegistry.start_link()
    {:ok, []}
  end

  test "Start HWInterface. Connect to Pololu Maestro. Change actuator values" do
    actuator_name = :aileron
    hw_interface_config = TestConfigs.Actuation.get_hw_config_pololu()
    actuator_list = [actuator_name]
    channels_list = [0]
    failsafes_list = [0.5]
    sw_interface_config = TestConfigs.Actuation.get_sw_config_actuators(actuator_list, channels_list, failsafes_list)
    config = %{
      hw_interface: hw_interface_config,
      sw_interface: sw_interface_config
    }
    IO.puts("Connect servo to channel 0 if real actuation is desired")
    {:ok, process_id} = Actuation.System.start_link(config)
    Process.sleep(100)
    # Test actuator values
    actuator = Map.get(sw_interface_config.actuators, actuator_name)
    # With no valid commands, the actuator output should be the failsafe_cmd
    Process.sleep(150)
    failsafe_output = 0.5*(actuator.min_pw_ms + actuator.max_pw_ms)
    assert Actuation.HwInterface.get_output_for_actuator(actuator) == failsafe_output
    # Send min_cmd to Actuator
    MessageSorter.Sorter.add_message({:actuator_cmds, :aileron}, [0], 400, actuator.cmd_limit_min)
    Process.sleep(200)
    assert Actuation.HwInterface.get_output_for_actuator(actuator) == actuator.min_pw_ms
    MessageSorter.Sorter.add_message({:actuator_cmds, :aileron}, [0], 1000, actuator.cmd_limit_max)
    Process.sleep(300)
    assert Actuation.HwInterface.get_output_for_actuator(actuator) == actuator.max_pw_ms
  end
end
