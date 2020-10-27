defmodule ActuationCommand.FrskyrxFrskyservoReadWriteTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(100)
    {:ok, []}
  end

  test "Receive Single Message" do
    Logger.info("Receive Single Message test")
    model_type = :Cessna
    node_type = :all
    act_config = Configuration.Module.Actuation.get_config(model_type, node_type)
    Actuation.System.start_link(act_config)
    {act_module, act_op_config} = Configuration.Module.Peripherals.Uart.get_module_key_and_config_for_module(:FrskyRxFrskyServo, node_type)
    module = Module.concat(Peripherals.Uart, act_module)
    |> Module.concat(Operator)
    apply(module, :start_link, [act_op_config])
    Process.sleep(1000)
    actuators = act_config.sw_interface.actuators.indirect
    |> Map.merge(act_config.sw_interface.actuators.direct)

    Logger.debug("actuators: #{inspect(actuators)}")
    fixed_output = %{aileron: 0.1, elevator: 0.2, throttle: 0.3, rudder: 0.4}
    Enum.each(0..10000, fn index ->
      channels_values = apply(module, :get_values_for_all_channels, [])
      unless Enum.empty?(channels_values) do
        output =
          Enum.reduce(actuators, %{}, fn ({name, actuator}, acc) ->
            value = Enum.at(channels_values, actuator.channel_number)
            # Logger.info("#{value}")
            value = (value + 1.0)*0.5
            # Actuation.HwInterface.set_output_for_actuator(actuator, name, output)
            if is_nil(value) do
              acc
            else
              Map.put(acc, name, {actuator, value})
            end
          end)
        # Logger.debug("output: #{inspect(output)}")
        apply(module, :update_actuators, [output])
      end
      # value = index/10000
      # value = (value + 1.0)*0.5
      # Logger.debug("#{value}")
      Process.sleep(20)
      # Actuation.HwInterface.set_output_for_actuator(aileron, :aileron, value)
    end)


    # Enum.each(0..10000, fn _index ->
    #   Logger.debug("#{Peripherals.Uart.FrskyRx.get_value_for_channel(4)}")
    #   Process.sleep(20)
    # end)
  end
end
