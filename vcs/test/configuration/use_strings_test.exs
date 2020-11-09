defmodule Configuration.UseStringsTest do
  use ExUnit.Case
  require Logger


  test "Uart configurations" do
    RingLogger.attach()
    Comms.ProcessRegistry.start_link()
    Comms.System.start_link()
    Process.sleep(200)
    devices_modules_speeds = [
      # {"Dsm", Command.Rx, 115_200},
      # {"FrskyRx", Command.Rx, 100_000},
      # {"FrskyServo", Actuation, 115_200},
      # {"PololuServo", Actuation, 115_200},
      # {"DsmRxFrskyServo", ActuationCommand, 115_200},
      # {"FrskyRxFrskyServo", ActuationCommand, 115_200},
      # {"TerarangerEvo", Estimation.TerarangerEvo, 115_200},
      # {"VnIns", Estimation.VnIns, 115_200},
      # {"VnImu", Estimation.VnIns, 115_200},
      # {"Xbee", Telemetry, 57_600},
      # {"Sik", Telemetry, 57_600},
      {"PwmReader", PwmReader, 115_200}
    ]


    Enum.each(devices_modules_speeds, fn {device, exp_module, exp_speed} ->
      port = (:rand.uniform(3) + 2)
      port_str = Integer.to_string(port)
      {module, config} = Configuration.Module.Peripherals.Uart.get_module_key_and_config(device, port_str)
      assert module == exp_module
      assert config.uart_port == "ttyAMA#{port-2}"
      assert config.port_options[:speed] == exp_speed
      module = Module.concat(Peripherals.Uart, module)
      |> Module.concat(Operator)
      apply(module, :start_link, [config])
    end)
    Process.sleep(500)
  end
end
