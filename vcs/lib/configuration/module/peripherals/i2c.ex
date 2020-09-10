defmodule Configuration.Module.Peripherals.I2c do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    peripherals = Common.Utils.Configuration.get_i2c_peripherals()
    Logger.info("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, %{}, fn (module, acc) ->
      {module_key, module_config} =
        case module do
          :Ina260 -> {Health.Ina260, get_ina260_config()}
        end
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_ina260_config() :: map()
  def get_ina260_config() do
    %{
      read_voltage_interval_ms: 1000,
      read_current_interval_ms: 200
    }
  end
end
