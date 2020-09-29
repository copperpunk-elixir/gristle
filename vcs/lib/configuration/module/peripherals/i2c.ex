defmodule Configuration.Module.Peripherals.I2c do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_model_type, node_type) do
    subdirectory = Atom.to_string(node_type)
    peripherals = Common.Utils.Configuration.get_i2c_peripherals(subdirectory)
    Logger.debug("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, %{}, fn (name, acc) ->
      peripheral_string = Atom.to_string(name)
      device_and_metadata = String.split(peripheral_string, "_")
      device = Enum.at(device_and_metadata,0)
      {module_key, module_config} =
        case device do
          "Ina260" ->
            metadata = Enum.at(device_and_metadata,1)
            [type, channel] = String.split(metadata,"-")
            channel = String.to_integer(channel)
            {Health.Ina260, get_ina260_config(type, channel)}
          "Ads1015-45" ->
            metadata = Enum.at(device_and_metadata,1)
            [type, channel] = String.split(metadata,"-")
            channel = String.to_integer(channel)
            {Health.Ads1015, get_ads1015_config(type, channel, 45)}
          "Ads1015-90" ->
            metadata = Enum.at(device_and_metadata,1)
            [type, channel] = String.split(metadata,"-")
            channel = String.to_integer(channel)
            {Health.Ads1015, get_ads1015_config(type, channel, 90)}

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
      read_current_interval_ms: 1000
    }
  end

  @spec get_ads1015_config(atom(), integer(), integer()) :: map()
  def get_ads1015_config(battery_type, channel, version) do
    {voltage_mult, current_mult} =
      case version do
        180 -> {1.0/63.69, 1.0/18.3}
        90 -> {1.0/63.69, 1.0/36.6}
        45 -> {1.0/242.3, 1.0/73.2}
        _other -> raise "Incorrect Voltage/Current measurement settings for Ads1015"
      end
    Logger.debug("Ads1015 version: #{version}")
    Logger.debug("V/I mults: #{voltage_mult}/#{current_mult}")
    %{
      battery_type: String.to_atom(battery_type),
      battery_channel: channel,
      read_battery_interval_ms: 1000,
      voltage_mult: voltage_mult,
      current_mult: current_mult
    }
  end

end
