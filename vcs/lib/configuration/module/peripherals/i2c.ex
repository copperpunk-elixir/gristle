defmodule Configuration.Module.Peripherals.I2c do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_model_type, _node_type) do
    peripherals = Common.Utils.Configuration.get_i2c_peripherals()
    Logger.info("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, %{}, fn (name, acc) ->
      peripheral_string = Atom.to_string(name)
      device_and_metadata = String.split(peripheral_string, "_")
      device = Enum.at(device_and_metadata,0)
      {module_key, module_config} =
        case device do
          "Ina260" ->
            metadata = Enum.at(device_and_metadata,1)
            [type, channel] = String.split(metadata,"-")
            {Health.Ina260, get_ina260_config(type, channel)}
        end
      Map.put(acc, module_key, module_config)
    end)
  end

  @spec get_ina260_config(atom(), integer()) :: map()
  def get_ina260_config(battery_type, channel) do
    %{
      battery_type: String.to_atom(battery_type),
      battery_channel: channel,
      read_voltage_interval_ms: 1000,
      read_current_interval_ms: 200
    }
  end
end
