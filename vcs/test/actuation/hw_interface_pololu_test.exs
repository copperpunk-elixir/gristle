defmodule Actuation.HwInterfacePololuTest do
  use ExUnit.Case

  setup do
    {:ok, [
        config: %{
          hw_interface: %{
            interface_driver_name: :pololu
          },
          aileron_actuator: %{
            channel_number: 0,
            reversed: false,
            min_pw_ms: 1100,
            max_pw_ms: 1900,
            cmd_limit_min: 0,
            cmd_limit_max: 1,
            failsafe_cmd: 0.5
          }
        }
      ]}
  end

  test "Start HWInterface. Connect to Pololu Maestro. Change actuator values", context do
    IO.puts("Connect servo to channel 0 if real actuation is desired")
    config = context[:config]
    {:ok, process_id} = Actuation.HwInterface.start_link(config.hw_interface)
    Common.Utils.wait_for_genserver_start(process_id)
    Process.sleep(100)
    aileron = config.aileron_actuator
    # Set output to min_value
    Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_min)
    assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.min_pw_ms
    Process.sleep(100)
    # Set output to max value
    Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_max)
    assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.max_pw_ms
    Process.sleep(100)
    # Set output to neutral value
    Actuation.HwInterface.set_output_for_actuator(aileron, 0.5*(aileron.cmd_limit_min + aileron.cmd_limit_max))
    assert Actuation.HwInterface.get_output_for_actuator(aileron) == 0.5*(aileron.min_pw_ms + aileron.max_pw_ms)
    Process.sleep(100)
    # Reverse servo and set to min value -> should yield
    aileron = %{aileron | reversed: true}
    Actuation.HwInterface.set_output_for_actuator(aileron, aileron.cmd_limit_min)
    assert Actuation.HwInterface.get_output_for_actuator(aileron) == aileron.max_pw_ms
  end
end
