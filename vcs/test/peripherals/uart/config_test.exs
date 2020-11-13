defmodule Peripherals.Uart.ConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    Common.Utils.common_startup()
    RingLogger.attach()
    model_type = "T28"
    {:ok, [model_type: model_type]}
  end

  test "All test", context do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    model_type = context[:model_type]
    config = Configuration.Module.get_config(Peripherals.Uart, model_type, "all")
    Logger.debug("config: #{inspect(config)}")
    assert config[Command.Rx][:uart_port] == "CP2104"
    assert config[Actuation][:uart_port] == "Feather M0"
    assert config[ActuationCommand][:uart_port] == "Feather M0"
    assert config[Estimation.TerarangerEvo][:uart_port] == "FT232R"
    assert config[Telemetry][:uart_port] == "FT231X"
    assert config[PwmReader][:uart_port] == "Feather M0"
    Process.sleep(200)
  end
end
