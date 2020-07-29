defmodule Actuation.CombinedWithFrskyTest do
  use ExUnit.Case
  require Logger
  setup do
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    {:ok, []}
  end

  test "Combined with FrSky test" do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    config = Configuration.Module.get_config(Actuation, :Plane, :all)
    Actuation.HwInterface.start_link(config.hw_interface)

    Process.sleep(500)
    Peripherals.Uart.FrskyRx.start_link(%{device_description: "Feather", publish_rx_output_loop_interval_ms: 50})

    Process.sleep(500)
    # Process.sleep(4000)
    actuators = config.sw_interface.actuators
    output = %{aileron: 0.1, elevator: 0.2, throttle: 0.3, rudder: 0.4}
    # Enum.each(actuators, fn {name, actuator} ->
    #   Actuation.HwInterface.set_output_for_actuator(actuator, name, Map.get(output, name))
    # end)
    # Enum.each(0..10, fn _index ->
    #   Actuation.HwInterface.update_actuators()
    #   Process.sleep(100)
    # end)
    Enum.each(0..10000, fn index ->
      Enum.each(actuators, fn {name, actuator} ->
        output = Peripherals.Uart.FrskyRx.get_value_for_channel(actuator.channel_number)
        Actuation.HwInterface.set_output_for_actuator(actuator, name, output)
      end)
      Actuation.HwInterface.update_actuators()
      # value = index/10000
      # value = (value + 1.0)*0.5
      # Logger.debug("#{value}")
      Process.sleep(20)
      # Actuation.HwInterface.set_output_for_actuator(aileron, :aileron, value)
    end)

  end
end
