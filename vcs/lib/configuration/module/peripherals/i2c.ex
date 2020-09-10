defmodule Configuration.Module.Peripherals.I2c do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_vehicle_type, node_type) do
    peripherals = Common.Utils.Configuration.get_i2c_peripherals()
    Logger.info("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, %{}, fn (name, acc) ->
      peripheral_string = Atom.to_string(name)
      type_and_sub_type = String.split(peripheral_string, "_")
      type = Enum.at(type_and_sub_type,0)
      sub_type = Enum.at(type_and_sub_type,1)
      {module_key, module_config} =
        case type do
          "Ina260" -> {Health.Ina260, get_ina260_config(sub_type)}
        end
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_ina260_config(atom()) :: map()
  def get_ina260_config(battery_type) do
    %{
      battery_type: String.to_atom(battery_type),
      read_voltage_interval_ms: 1000,
      read_current_interval_ms: 200
    }
  end
end
