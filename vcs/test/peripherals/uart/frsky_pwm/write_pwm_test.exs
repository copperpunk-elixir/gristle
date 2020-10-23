defmodule Peripherals.FrskyPwm.WritePwmTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Write Frsky PWM Message test" do
    Logger.info("Write Frsky PWM Message test")
    model_type = :Cessna
    node_type = :all
    act_config = Configuration.Module.Actuation.get_config(model_type, node_type)
    Actuation.System.start_link(act_config)
    {_act_module, act_op_config} = Configuration.Module.Peripherals.Uart.get_module_key_and_config_for_module(:FrskyServo, node_type)
    Peripherals.Uart.Actuation.Operator.start_link(act_op_config)

    actuators = act_config.sw_interface.actuators.indirect
    fixed_output = %{aileron: 0.1, elevator: 0.2, throttle: 0.3, rudder: 0.4}
    Enum.each(0..10000, fn index ->
      output =
        Enum.reduce(actuators, %{}, fn ({name, actuator}, acc) ->
          value = Map.get(fixed_output, name, 0)# :random.uniform()
          # Actuation.HwInterface.set_output_for_actuator(actuator, name, output)
          Map.put(acc, name, {actuator, value})
        end)
      # Logger.debug("output: #{inspect(output)}")
      Peripherals.Uart.Actuation.Operator.update_actuators(output)
      # value = index/10000
      # value = (value + 1.0)*0.5
      # Logger.debug("#{value}")
      Process.sleep(50)
      # Actuation.HwInterface.set_output_for_actuator(aileron, :aileron, value)
    end)


    # Enum.each(0..10000, fn _index ->
    #   Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
    #   Process.sleep(20)
    # end)
  end
end
